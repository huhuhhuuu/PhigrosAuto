#import <Foundation/Foundation.h>

// 自适应解析：在运行时把 JudgeManager / Note 的类、字段偏移、时间字段找出来。
// 全部靠候选名列表探测，命中即锁定；日志会打印实际命中的组合，便于固化到 Config.h。

typedef struct {
    BOOL   resolved;

    void  *managerClass;
    void  *noteClass;
    void  *managerInstance;      // 场景里的实例（MonoBehaviour）

    int    offNoteList;          // List<Note> 字段
    int    offTime;              // 当前音乐时间
    int    offCombo;
    int    offScore;
    BOOL   timeIsDouble;         // 时间字段是 double 还是 float
    BOOL   timeTypeKnown;        // 是否由 il2cpp 元数据权威判定

    int    offNoteTime;
    int    offNoteHold;
    int    offNoteX;
    int    offNoteType;
    int    offNoteDone;
    BOOL   noteTimeIsDouble, noteTimeTypeKnown;
    BOOL   noteHoldIsDouble, noteHoldTypeKnown;

    char   managerName[96];      // 命中的 ns.name，日志用
} PHModel;

PHModel *PHModelShared(void);
BOOL     PHModelResolve(void);            // 探测一次，成功置 resolved
BOOL     PHModelRefreshInstance(void);    // 场景切换后重新取实例

// 收集所有音符对象指针，返回个数
int      PHModelCollectNotes(void ***outNotes, int cap);
double   PHModelNow(void);                // 音乐时间（秒）
int      PHModelCombo(void);
int      PHModelScore(void);
float    PHModelNoteX(void *note);
double   PHModelNoteTime(void *note);     // 音符判定时刻（秒）
double   PHModelNoteHold(void *note);     // 长条时长，非长条返回 0
int      PHModelNoteType(void *note);     // 命中 type 字段返回枚举，否则 kUnknownType
BOOL     PHModelNoteDone(void *note);
