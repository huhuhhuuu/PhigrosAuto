#import <Foundation/Foundation.h>

// 自动打歌调度器：每帧读在谱音符，按音乐时间合成触点。
// 判定只看时间差，所以落点只需落在游玩区内；位置只影响视觉与多指区分。

void PHAutoplaySetEnabled(BOOL on);
BOOL PHAutoplayIsEnabled(void);
void PHAutoplayTick(void);        // 由 CADisplayLink 在主线程每帧调用
void PHAutoplayReset(void);       // 换曲 / 重开时清状态并抬起所有触点
void PHAutoplaySetVerbose(BOOL v);
