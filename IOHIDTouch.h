#import <Foundation/Foundation.h>

// IOHIDEvent 数字转换器注入（系统级触点合成）。
// 走 /dev/input 之上的 IOHIDEvent 通路，绕过 UIKit 手势层，
// 时序抖动可压到 1~2ms，且在 120Hz 下不会被 accessibility 节流。

BOOL   PHTouchInit(void);      // 建立 event system client
void   PHTouchDown(int slot, double x, double y);
void   PHTouchMove(int slot, double x, double y);
void   PHTouchUp(int slot, double x, double y);
void   PHTouchReleaseAll(void);
