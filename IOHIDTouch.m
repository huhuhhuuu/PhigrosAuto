#import "IOHIDTouch.h"
#import "Config.h"
#import <dlfcn.h>
#import <stdbool.h>
#import <mach/mach_time.h>

// ---------------- 私有类型与符号 ----------------
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

typedef IOHIDEventRef (*t_ClientCreateEvent)(CFAllocatorRef, uint64_t, uint32_t, uint32_t,
                                             uint32_t, uint32_t, uint32_t,
                                             double, double, double, double, double,
                                             bool, bool, uint32_t);
// 单指变体：参数比 DigitizerEvent 少，iOS 15+ 起可用
typedef IOHIDEventRef (*t_FingerEvent)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, bool);
typedef void (*t_SetFloat)(IOHIDEventRef, uint32_t, double);
typedef void (*t_SetInt)(IOHIDEventRef, uint32_t, int64_t);
typedef void (*t_Append)(IOHIDEventRef, IOHIDEventRef);
typedef IOHIDEventSystemClientRef (*t_ClientCreate)(CFAllocatorRef);
// iOS 16+ 有带 type 的变体：type 0 = 保留旧行为的多点触控客户端
typedef IOHIDEventSystemClientRef (*t_ClientCreateType)(CFAllocatorRef, int32_t);
typedef void (*t_Dispatch)(IOHIDEventSystemClientRef, IOHIDEventRef);

static t_ClientCreateEvent pCreateDigitizerEvent;
static t_FingerEvent       pFingerEvent;
static t_SetFloat          pSetFloat;
static t_SetInt            pSetInt;
static t_Append            pAppend;
static t_ClientCreate      pClientCreate;
static t_ClientCreateType  pClientCreateType;
static t_Dispatch          pDispatch;

static IOHIDEventSystemClientRef gClient;
static BOOL gTouchReady = NO;
static BOOL gUseFingerEvent = NO;

// ---------------- 字段常量 ----------------
// IOHIDEventField = (eventType << 16) | offset
#define PH_EVENT_TYPE_DIGITIZER 11u
#define PH_FIELD(t, o) (((uint32_t)(t) << 16) | (uint32_t)(o))

enum {
    kF_X        = PH_FIELD(PH_EVENT_TYPE_DIGITIZER, 0x02),   // kIOHIDEventFieldDigitizerX
    kF_Y        = PH_FIELD(PH_EVENT_TYPE_DIGITIZER, 0x03),   // Y
    kF_Z        = PH_FIELD(PH_EVENT_TYPE_DIGITIZER, 0x04),   // Z
    kF_Index    = PH_FIELD(PH_EVENT_TYPE_DIGITIZER, 0x07),   // index（区分多指）
    kF_Identity = PH_FIELD(PH_EVENT_TYPE_DIGITIZER, 0x08),   // identity
    kF_Integrated = PH_FIELD(PH_EVENT_TYPE_DIGITIZER, 0x0C), // isDisplayIntegrated
    kF_Range    = PH_FIELD(PH_EVENT_TYPE_DIGITIZER, 0x0D),   // range（部分版本判抬起用）
    kF_Pressure = PH_FIELD(PH_EVENT_TYPE_DIGITIZER, 0x11),   // tipPressure
};

// 数字转换器类型：Finger=2  Hand=3  Puck=4  Stylus=5
#define PH_TRANSDUCER_HAND 3u

BOOL PHTouchInit(void) {
    if (gTouchReady) return YES;

    void *h = dlopen("/System/Library/PrivateFrameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!h) h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!h) return NO;

    pCreateDigitizerEvent = (t_ClientCreateEvent)dlsym(h, "IOHIDEventCreateDigitizerEvent");
    pFingerEvent  = (t_FingerEvent)dlsym(h, "IOHIDEventCreateDigitizerFingerEvent");
    pSetFloat = (t_SetFloat)dlsym(h, "IOHIDEventSetFloatValue");
    pSetInt   = (t_SetInt)dlsym(h, "IOHIDEventSetIntegerValue");
    pAppend   = (t_Append)dlsym(h, "IOHIDEventAppendEvent");
    pClientCreate = (t_ClientCreate)dlsym(h, "IOHIDEventSystemClientCreate");
    pClientCreateType = (t_ClientCreateType)dlsym(h, "IOHIDEventSystemClientCreateSimpleClient");
    if (!pClientCreateType)
        pClientCreateType = (t_ClientCreateType)dlsym(h, "IOHIDEventSystemClientCreateWithType");
    pDispatch = (t_Dispatch)dlsym(h, "IOHIDEventSystemClientDispatchEvent");

    if ((!pCreateDigitizerEvent && !pFingerEvent) || !pSetFloat || !pSetInt ||
        !pDispatch || (!pClientCreate && !pClientCreateType))
        return NO;

    // 客户端创建顺序：先试带 type 的新变体，失败退回旧签名
    if (pClientCreateType) gClient = pClientCreateType(kCFAllocatorDefault, 0);
    if (!gClient && pClientCreate) gClient = pClientCreate(kCFAllocatorDefault);
    if (!gClient) return NO;

    // 有多指 DigitizerEvent 就优先用；没有则退回单指 FingerEvent
    gUseFingerEvent = (pCreateDigitizerEvent == NULL);

    gTouchReady = YES;
    return YES;
}

static IOHIDEventRef PHMakeHandEvent(BOOL down, int slot, double x, double y) {
    IOHIDEventRef ev = NULL;

    if (!gUseFingerEvent) {
        // eventMask 与 range/touch 决定这是"按下"还是"抬起"
        ev = pCreateDigitizerEvent(kCFAllocatorDefault,
                                   mach_absolute_time(),
                                   PH_TRANSDUCER_HAND,
                                   (uint32_t)slot,          // index
                                   (uint32_t)(0x100 + slot),// identity
                                   0, 0,                    // eventMask, buttonMask
                                   x, y, 0,                 // x, y, z
                                   down ? 1.0 : 0.0,        // tipPressure
                                   0.0,                     // barrelPressure
                                   down ? true : false,     // range
                                   down ? true : false,     // touch
                                   0);                      // options
    } else if (pFingerEvent) {
        // 单指变体：无 index/identity 参数，靠 setFloat/setInt 补
        ev = pFingerEvent(kCFAllocatorDefault,
                          mach_absolute_time(),
                          (uint32_t)slot,
                          (uint32_t)(0x100 + slot),
                          down ? true : false);
    }

    if (!ev) return NULL;
    pSetFloat(ev, kF_X, x);
    pSetFloat(ev, kF_Y, y);
    pSetFloat(ev, kF_Z, 0.0);
    pSetFloat(ev, kF_Pressure, down ? 1.0 : 0.0);
    pSetInt(ev, kF_Index, slot);
    pSetInt(ev, kF_Identity, 0x100 + slot);
    pSetInt(ev, kF_Integrated, 1);
    if (down) pSetInt(ev, kF_Range, 1);   // 部分 iOS 版本靠 range 判抬起
    return ev;
}

static void PHPost(IOHIDEventRef ev) {
    if (!ev || !gClient) return;
    pDispatch(gClient, ev);
    CFRelease(ev);
}

void PHTouchDown(int slot, double x, double y) {
    if (!gTouchReady && !PHTouchInit()) return;
    if (slot < 0 || slot >= kMaxTouchSlots) return;
    PHPost(PHMakeHandEvent(YES, slot, x, y));
}

void PHTouchMove(int slot, double x, double y) {
    if (!gTouchReady) return;
    if (slot < 0 || slot >= kMaxTouchSlots) return;
    PHPost(PHMakeHandEvent(YES, slot, x, y));   // 移动 = 保持按下的位置更新
}

void PHTouchUp(int slot, double x, double y) {
    if (!gTouchReady) return;
    if (slot < 0 || slot >= kMaxTouchSlots) return;
    PHPost(PHMakeHandEvent(NO, slot, x, y));    // range/touch 均置 0 = 抬起
}

void PHTouchReleaseAll(void) {
    for (int i = 0; i < kMaxTouchSlots; i++) PHTouchUp(i, 0, 0);
}
