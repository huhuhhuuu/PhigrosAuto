#import "Autoplay.h"
#import "NoteModel.h"
#import "IOHIDTouch.h"
#import "Config.h"
#import <UIKit/UIKit.h>
#import <string.h>

typedef struct {
    BOOL    active;
    void   *note;
    int     slot;
    double  releaseAt;
    double  x, y;
    BOOL    isFlick;
    BOOL    flickDone;
} PHActiveTouch;

static PHActiveTouch gSlots[kMaxTouchSlots];
static BOOL          gEnabled = NO;
static BOOL          gVerbose = NO;
static CFMutableSetRef gHandled = NULL;   // 已经按过的音符（原始指针集合）
static int32_t       gLastCount = -1;
static void         *gLastFirst = NULL;

static void PHLog(NSString *fmt, ...) {
    if (!gVerbose) return;
    va_list ap; va_start(ap, fmt);
    NSLog(@"[PhigrosAuto] %@", [[NSString alloc] initWithFormat:fmt arguments:ap]);
    va_end(ap);
}

// ---------------- 坐标映射 ----------------
// positionX 为 0..1 的归一化值时，kPlayfieldWidth 取 1.0；
// 若游戏里是像素/世界坐标，把 kPlayfieldWidth 设成对应宽度（>1），这里按线性映射。
static double PHMapScreenX(float posX) {
    CGSize sz = [UIScreen mainScreen].bounds.size;
    if (kPlayfieldWidth > 1.0) {
        return kPlayfieldLeft + (double)posX;          // 已是像素
    }
    double nx = kPlayfieldLeft + (double)posX * kPlayfieldWidth;
    if (nx < 0.0) nx = 0.0;
    if (nx > 1.0) nx = 1.0;
    return nx * sz.width;
}

static double PHMapScreenY(int slot) {
    CGSize sz = [UIScreen mainScreen].bounds.size;
    return sz.height * kTouchYRatio + slot * kTouchYSpread;
}

// ---------------- 状态 ----------------
static void PHHandledInit(void) {
    if (!gHandled) gHandled = CFSetCreateMutable(kCFAllocatorDefault, 0, NULL);
}

static BOOL PHHandledContains(void *note) {
    return gHandled && CFSetContainsValue(gHandled, note);
}

static void PHHandledAdd(void *note) {
    PHHandledInit();
    if (CFSetGetCount(gHandled) > kHandledCap) CFSetRemoveAllValues(gHandled);
    CFSetAddValue(gHandled, note);
}

void PHAutoplayReset(void) {
    for (int i = 0; i < kMaxTouchSlots; i++) {
        if (gSlots[i].active) PHTouchUp(i, gSlots[i].x, gSlots[i].y);
        memset(&gSlots[i], 0, sizeof(gSlots[i]));
        gSlots[i].slot = i;
    }
    if (gHandled) CFSetRemoveAllValues(gHandled);
    gLastCount = -1;
    gLastFirst = NULL;
}

void PHAutoplaySetEnabled(BOOL on) {
    gEnabled = on;
    if (!on) PHAutoplayReset();
    PHLog(@"autoplay %@", on ? @"ON" : @"OFF");
}

BOOL PHAutoplayIsEnabled(void) { return gEnabled; }
void PHAutoplaySetVerbose(BOOL v) { gVerbose = v; }

static int PHAllocSlot(void) {
    for (int i = 0; i < kMaxTouchSlots; i++) if (!gSlots[i].active) return i;
    return -1;
}

// 换曲检测：音符表在游戏里可能是动态收缩的活跃表，不能一见数量变化就清记账。
// 只在两种情况下判定为换曲：时间倒流，或首元素变了且数量差异超过 30%。
static double gLastTickTime = 0.0;
static void PHDetectChartChange(int count, void **items, double now) {
    void *first = (count > 0 && items) ? items[0] : NULL;

    BOOL timeBack = (now + 0.5 < gLastTickTime);
    BOOL hugeShift = (gLastCount > 0 && count > 0 && first != gLastFirst &&
                      (count < gLastCount * 7 / 10 || count > gLastCount * 13 / 10));

    if (gLastCount >= 0 && (timeBack || hugeShift)) {
        PHLog(@"chart changed (timeBack=%d hugeShift=%d count %d->%d)", timeBack, hugeShift, gLastCount, count);
        PHAutoplayReset();
    }

    gLastCount = count;
    gLastFirst = first;
    gLastTickTime = now;
}

// ---------------- 主循环 ----------------
void PHAutoplayTick(void) {
    if (!gEnabled) return;
    if (!PHModelResolve()) return;

    void **notes = NULL;
    int n = PHModelCollectNotes(&notes, 8192);
    if (n <= 0) return;
    double now = PHModelNow();
    PHDetectChartChange(n, notes, now);
    PHHandledInit();

    // 1) 松开到期的触点
    for (int i = 0; i < kMaxTouchSlots; i++) {
        PHActiveTouch *s = &gSlots[i];
        if (!s->active) continue;
        if (now < s->releaseAt) continue;

        if (s->isFlick && !s->flickDone) {
            PHTouchMove(i, s->x, s->y - kFlickDistance);   // 向上划，滑键保险
            s->flickDone = YES;
            s->releaseAt = now + kFlickMoveSeconds;
            continue;
        }
        PHTouchUp(i, s->x, s->y);
        memset(s, 0, sizeof(*s));
        s->slot = i;
    }

    // 2) 扫描新音符
    for (int k = 0; k < n; k++) {
        void *note = notes[k];
        if (!note) continue;
        if (PHHandledContains(note)) continue;
        if (PHModelNoteDone(note)) { PHHandledAdd(note); continue; }

        double t    = PHModelNoteTime(note);
        double hold = PHModelNoteHold(note);

        // 还没到判定窗口
        if (now < t + kHitAdvance) continue;
        // 已经过去太久（暂停恢复 / 掉帧）就不补按了，避免一堆音符同时触发
        if (now > t + 0.25) { PHHandledAdd(note); continue; }

        int slot = PHAllocSlot();
        if (slot < 0) continue;   // 触点用尽，下一帧再试

        PHActiveTouch *s = &gSlots[slot];
        s->active  = YES;
        s->note    = note;
        s->slot    = slot;
        s->x       = PHMapScreenX(PHModelNoteX(note));
        s->y       = PHMapScreenY(slot);
        s->isFlick = (PHModelNoteType(note) == kNoteTypeFlick);
        s->flickDone = NO;

        PHTouchDown(slot, s->x, s->y);

        if (hold > 0.0) {
            s->releaseAt = t + hold + kHoldTailSeconds;
        } else if (s->isFlick) {
            s->releaseAt = now + kFlickMoveSeconds;
        } else {
            s->releaseAt = now + kTapHoldSeconds;
        }

        PHHandledAdd(note);
        PHLog(@"hit t=%.3f now=%.3f hold=%.3f slot=%d x=%.1f", t, now, hold, slot, s->x);
    }
}
