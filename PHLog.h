#ifndef PHLOG_H
#define PHLOG_H

#import <Foundation/Foundation.h>

// ============================================================
// 统一日志出口
//
// 为什么不能只靠 NSLog：
//   iOS 17 起系统不再把 NSLog 落盘到 /var/log/syslog，
//   NSLog 只进 os_log 环形缓冲，设备上 `grep /var/log/syslog`
//   永远抓不到。要在终端里直接看，插件必须自己写文件。
//
// 所以这里双写：
//   1) /var/mobile/PhigrosAuto.log  —— 终端里 cat 就能看
//   2) NSLog                        —— 仍进 os_log，保留给 idevicesyslog
// ============================================================

void PHLogInit(void);
void PHLogWrite(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
const char *PHLogCurrentPath(void);   // 实际生效的日志路径（沙盒内外不同）

// 心跳标记：证明 dylib 被执行过。放在 App 容器 tmp/ 下，几乎不会失败。
// 只要 /var/mobile/Containers/Data/Application/*/tmp/PhigrosAuto.marker
// 存在，就说明注入成功，与面板/il2cpp 无关。
void PHWriteHeartbeat(const char *tag);

// 日志会按可写性依次尝试以下位置，第一个能打开的生效：
//   1) 自身沙盒 Documents/PhigrosAuto.log
//   2) /var/mobile/Media/PhigrosAuto.log
//   3) /var/mobile/PhigrosAuto.log
//   4) /tmp/PhigrosAuto.log
#define PH_LOG_PATH "/var/mobile/PhigrosAuto.log"

#endif
