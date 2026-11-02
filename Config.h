#ifndef PHIGROS_CONFIG_H
#define PHIGROS_CONFIG_H

// ============================================================
// 一、行为参数（真机上手后主要调这三个）
// ============================================================

// 单点按压时长（秒）。低于 0.025 部分机型会丢帧到"抬手无判定"
#define kTapHoldSeconds     0.040
// 长条/滑键尾部延长，抵消最后一帧的时间抖
#define kHoldTailSeconds    0.020
// 触发提前量：负值=提前按（补偿 IOHID 派发延迟），正值=延后
#define kHitAdvance         (-0.004)
// 滑键（flick）位移时长与距离（屏幕点）
#define kFlickMoveSeconds   0.018
#define kFlickDistance      60.0
// 同时按住的触点数上限
#define kMaxTouchSlots      10
// 已打过音符的记账表上限，超过即清空（防内存增长）
#define kHandledCap         20000
// 帧驱动频率上限：0 = 跟随屏幕刷新（ProMotion 为 120Hz），限帧填 60
#define kTickRateCap        0

// ============================================================
// 二、运行时探测候选名
//    每个数组按顺序尝试，第一个全部命中（类 + List 字段 + 时间字段）
//    的组合即锁定。全部失败时跑 discover.js，把真实名字补到最前面。
// ============================================================

typedef struct { const char *ns; const char *name; } PHClassName;

// 判定/谱面管理器候选
static const PHClassName kManagerClasses[] = {
    { "Assets.Scripts.InGame.Judgement", "JudgeManager" },
    { "Assets.Scripts.InGame.Judgement", "JudgementManager" },
    { "Assets.Scripts.InGame.Judgement", "JudgeManagerV2" },
    { "Assets.Scripts.InGame.Notes",     "NoteManager" },
    { "",                                "JudgeManager" },
    { "",                                "JudgementManager" },
    { "",                                "NoteManager" },
    { NULL, NULL }
};

// 管理器上"在谱音符列表"字段候选（类型 List<Note>）
static const char *kNoteListFields[] = {
    "notes", "noteList", "allNotes", "m_Notes", "noteDataList", "runtimeNotes", NULL
};

// 管理器上"当前音乐时间"字段候选（float 或 double）
static const char *kTimeFields[] = {
    "time", "currentTime", "musicTime", "songTime", "audioTime", "m_Time",
    "curTime", "playTime", NULL
};

// 管理器上连击/分数字段候选（仅用于日志与自检，不写回）
static const char *kComboFields[] = { "combo", "curCombo", "currentCombo", NULL };
static const char *kScoreFields[] = { "score", "curScore", "currentScore", NULL };

// 单例静态字段候选（MonoBehaviour 单例；失败则退回 FindObjectOfType）
static const char *kSingletonFields[] = {
    "instance", "Instance", "_instance", "s_instance", "current", NULL
};

// Note 类名候选（管理器里的元素类型解析失败时用这些直接找）
static const PHClassName kNoteClasses[] = {
    { "Assets.Scripts.InGame.Notes", "Note" },
    { "Assets.Scripts.InGame.Notes", "BaseNote" },
    { "",                            "Note" },
    { NULL, NULL }
};

// Note 字段候选
static const char *kNoteTimeFields[] = { "time", "startTime", "hitTime", "noteTime", "m_Time", NULL };
static const char *kNoteHoldFields[] = { "holdTime", "duration", "holdDuration", "length", "endTime", NULL };
static const char *kNoteXFields[]    = { "positionX", "noteX", "x", "posX", "m_X", NULL };
static const char *kNoteTypeFields[] = { "type", "noteType", "m_Type", NULL };
static const char *kNoteDoneFields[] = { "judged", "isJudged", "hasJudged", "hit", "isHit", NULL };

// NoteType 枚举序：命中 type 字段时用它区分 flick
// 0=Tap 1=Drag 2=Hold 3=Flick（版本差异时改这里）
enum { kNoteTypeTap = 0, kNoteTypeDrag = 1, kNoteTypeHold = 2, kNoteTypeFlick = 3 };
// type 为 -1（字段没解析到）时：holdTime > 0 一律按长条处理
#define kUnknownType (-1)

// ============================================================
// 三、屏幕坐标映射（触点落点）
//    判定只看时间，落点只需落在游玩区内、且避开暂停热区。
//    默认映射：x = kPlayfieldLeft + positionX * kPlayfieldWidth
//    真机上用"对准模式"打印 positionX 与期望像素，反过来校这两个数。
// ============================================================

#define kPlayfieldLeft      0.0
#define kPlayfieldWidth     1.0
// 触点 y（屏幕高度比例，0=顶部 1=底部）。0.62 大致落在判定区附近，不压暂停按钮
#define kTouchYRatio        0.62
// 多指之间的 y 微偏移，避免完全重合被判为同一点
#define kTouchYSpread       12.0

#endif
