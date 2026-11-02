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

// 当前日志文件绝对路径（终端里用）
#define PH_LOG_PATH "/var/mobile/PhigrosAuto.log"

#endif
