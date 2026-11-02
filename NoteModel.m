#import "NoteModel.h"
#import "IL2CPP.h"
#import "Config.h"
#import <string.h>
#import <stdio.h>
#import <stdarg.h>
#import <math.h>

static PHModel gModel;

PHModel *PHModelShared(void) { return &gModel; }

// 在候选字段名里找第一个能解析出偏移的；outName 回传命中的字段名
static int PHFirstFieldOff(void *klass, const char **cands, const char **outName) {
    if (outName) *outName = NULL;
    if (!klass) return -1;
    for (int i = 0; cands[i]; i++) {
        int off = PHFieldOffset(klass, cands[i]);
        if (off > 0) {
            if (outName) *outName = cands[i];
            return off;
        }
    }
    return -1;
}

// 取单例：静态字段优先，失败退回 FindObjectOfType
static void *PHManagerInstance(void *klass) {
    if (!klass) return NULL;

    for (int i = 0; kSingletonFields[i]; i++) {
        void *v = PHStaticFieldValue(klass, kSingletonFields[i]);
        if (v) {
            // 确认这个对象确实是该类（防静态字段是别的类型）
            if (PHClassOfObject(v) == klass) return v;
        }
    }
    return PHObjectFindByType(klass);
}

static void PHModelLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[PhigrosAuto] %@", s);
}

// 用 il2cpp 元数据的字段类型名判定 float/double，权威且无需猜测
static void PHApplyTypeInfo(const char *typeName, BOOL *isDouble, BOOL *known) {
    if (!typeName || !typeName[0]) { *known = NO; *isDouble = NO; return; }
    *known = YES;
    *isDouble = (strcmp(typeName, "System.Double") == 0);
}

BOOL PHModelResolve(void) {
    if (gModel.resolved) return YES;
    if (!PHL2CPPInit()) {
        PHModelLog(@"il2cpp 符号绑定失败（UnityFramework 未导出 il2cpp_* ？）");
        return NO;
    }

    for (int i = 0; kManagerClasses[i].name; i++) {
        const PHClassName *c = &kManagerClasses[i];
        void *klass = PHFindClass(c->ns, c->name);
        if (!klass) continue;

        const char *listName = NULL, *timeName = NULL;
        int offList = PHFirstFieldOff(klass, kNoteListFields, &listName);
        if (offList < 0) continue;

        int offTime = PHFirstFieldOff(klass, kTimeFields, &timeName);
        if (offTime < 0) {
            PHModelLog(@"%s 缺时间字段，跳过", c->name);
            continue;
        }

        void *inst = PHManagerInstance(klass);
        if (!inst) continue;

        gModel.managerClass    = klass;
        gModel.managerInstance = inst;
        gModel.offNoteList     = offList;
        gModel.offTime         = offTime;
        gModel.offCombo        = PHFirstFieldOff(klass, kComboFields, NULL);
        gModel.offScore        = PHFirstFieldOff(klass, kScoreFields, NULL);
        PHApplyTypeInfo(PHFieldTypeName(klass, timeName),
                        &gModel.timeIsDouble, &gModel.timeTypeKnown);
        snprintf(gModel.managerName, sizeof(gModel.managerName), "%s.%s", c->ns, c->name);

        // Note 类：候选名优先，其次读 list 元素的 klass
        void *noteClass = NULL;
        for (int j = 0; kNoteClasses[j].name; j++) {
            void *k = PHFindClass(kNoteClasses[j].ns, kNoteClasses[j].name);
            if (k && PHFieldOffset(k, kNoteTimeFields[0]) > 0) { noteClass = k; break; }
        }
        if (!noteClass) {
            void *list = *(void **)((char *)inst + offList);
            if (list) {
                int32_t n = PH_LIST_SIZE(list);
                void **items = PH_LIST_ITEMS(list);
                for (int32_t k = 0; k < n && items; k++) {
                    if (items[k]) { noteClass = PHClassOfObject(items[k]); break; }
                }
            }
        }
        if (!noteClass) {
            PHModelLog(@"找到管理器 %s 但无法定位 Note 类", gModel.managerName);
            continue;
        }

        const char *ntName = NULL, *nhName = NULL;
        int offNoteTime = PHFirstFieldOff(noteClass, kNoteTimeFields, &ntName);
        if (offNoteTime < 0) {
            PHModelLog(@"Note 类缺 time 字段");
            continue;
        }

        gModel.noteClass    = noteClass;
        gModel.offNoteTime  = offNoteTime;
        gModel.offNoteHold  = PHFirstFieldOff(noteClass, kNoteHoldFields, &nhName);
        gModel.offNoteX     = PHFirstFieldOff(noteClass, kNoteXFields, NULL);
        gModel.offNoteType  = PHFirstFieldOff(noteClass, kNoteTypeFields, NULL);
        gModel.offNoteDone  = PHFirstFieldOff(noteClass, kNoteDoneFields, NULL);
        PHApplyTypeInfo(PHFieldTypeName(noteClass, ntName),
                        &gModel.noteTimeIsDouble, &gModel.noteTimeTypeKnown);
        if (nhName)
            PHApplyTypeInfo(PHFieldTypeName(noteClass, nhName),
                            &gModel.noteHoldIsDouble, &gModel.noteHoldTypeKnown);
        gModel.resolved     = YES;

        PHModelLog(@"锁定 %s | %s@%d %s@%d(%s) combo@%d score@%d",
                   gModel.managerName, listName, offList, timeName, offTime,
                   gModel.timeTypeKnown ? (gModel.timeIsDouble ? "double" : "float") : "未定",
                   gModel.offCombo, gModel.offScore);
        PHModelLog(@"note %s t@%d(%s) hold@%d x@%d type@%d done@%d",
                   PHClassNameOf(noteClass), gModel.offNoteTime,
                   gModel.noteTimeTypeKnown ? (gModel.noteTimeIsDouble ? "double" : "float") : "未定",
                   gModel.offNoteHold, gModel.offNoteX, gModel.offNoteType, gModel.offNoteDone);
        return YES;
    }

    PHModelLog(@"候选类名全部未命中，跑 discover.js 取真实类名后补进 Config.h");
    return NO;
}

BOOL PHModelRefreshInstance(void) {
    if (!gModel.managerClass) return NO;
    void *inst = PHManagerInstance(gModel.managerClass);
    if (!inst) return NO;
    gModel.managerInstance = inst;
    return YES;
}

int PHModelCollectNotes(void ***outNotes, int cap) {
    *outNotes = NULL;
    if (!gModel.resolved || !gModel.managerInstance) return 0;
    void *list = *(void **)((char *)gModel.managerInstance + gModel.offNoteList);
    if (!list) return 0;
    int32_t n = PH_LIST_SIZE(list);
    void **items = PH_LIST_ITEMS(list);
    if (!items || n <= 0) return 0;
    if (n > cap) n = cap;
    *outNotes = items;
    return (int)n;
}

// 时间字段可能是 float 也可能是 double。优先用元数据类型名（resolve 阶段已判定）；
// 元数据拿不到时兜底：float 位型按 double 读会得到近零 denormal，据此反推。
static double gLastNow = 0.0;
static BOOL   gFallbackProbed = NO;
static BOOL   gFallbackIsDouble = NO;

static BOOL PHGuessDouble(double d) {
    if (!(d > -1000.0 && d < 100000.0)) return NO;   // NaN 与离谱值直接排除
    if (fabs(d) < 1e-30) return NO;                  // denormal → 实际是 float
    return YES;
}

double PHModelNow(void) {
    if (!gModel.resolved || !gModel.managerInstance) return 0.0;

    BOOL isDouble;
    if (gModel.timeTypeKnown) {
        isDouble = gModel.timeIsDouble;
    } else {
        if (!gFallbackProbed) {
            double d = PHReadF64(gModel.managerInstance, gModel.offTime);
            gFallbackIsDouble = PHGuessDouble(d);
            gFallbackProbed = YES;
            PHModelLog(@"时间字段类型未知，按 %s 兜底（d=%.6g）",
                       gFallbackIsDouble ? "double" : "float", d);
        }
        isDouble = gFallbackIsDouble;
    }

    double now = isDouble ? PHReadF64(gModel.managerInstance, gModel.offTime)
                          : (double)PHReadF32(gModel.managerInstance, gModel.offTime);

    // 时间倒流（重开 / 换曲）时允许重新判断
    if (now < gLastNow - 1.0) gFallbackProbed = NO;
    gLastNow = now;
    return now;
}

int PHModelCombo(void) {
    if (!gModel.resolved || !gModel.managerInstance || gModel.offCombo < 0) return 0;
    return PHReadI32(gModel.managerInstance, gModel.offCombo);
}

int PHModelScore(void) {
    if (!gModel.resolved || !gModel.managerInstance || gModel.offScore < 0) return 0;
    return PHReadI32(gModel.managerInstance, gModel.offScore);
}

float PHModelNoteX(void *note) {
    if (!note || gModel.offNoteX < 0) return 0.5f;
    return PHReadF32(note, gModel.offNoteX);
}

double PHModelNoteTime(void *note) {
    if (!note || gModel.offNoteTime < 0) return 0.0;
    BOOL isDouble = gModel.noteTimeTypeKnown ? gModel.noteTimeIsDouble
                                             : PHGuessDouble(PHReadF64(note, gModel.offNoteTime));
    return isDouble ? PHReadF64(note, gModel.offNoteTime)
                    : (double)PHReadF32(note, gModel.offNoteTime);
}

double PHModelNoteHold(void *note) {
    if (!note || gModel.offNoteHold < 0) return 0.0;
    BOOL isDouble = gModel.noteHoldTypeKnown ? gModel.noteHoldIsDouble
                                             : PHGuessDouble(PHReadF64(note, gModel.offNoteHold));
    double v = isDouble ? PHReadF64(note, gModel.offNoteHold)
                        : (double)PHReadF32(note, gModel.offNoteHold);
    return (v > 0.0) ? v : 0.0;
}

int PHModelNoteType(void *note) {
    if (!note || gModel.offNoteType < 0) return kUnknownType;
    return PHReadI32(note, gModel.offNoteType);
}

BOOL PHModelNoteDone(void *note) {
    if (!note || gModel.offNoteDone < 0) return NO;
    return PHReadU8(note, gModel.offNoteDone) != 0;
}
