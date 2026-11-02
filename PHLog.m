#import "PHLog.h"
#import <stdio.h>
#import <stdarg.h>
#import <unistd.h>
#import <sys/time.h>
#import <pthread.h>
#import <string.h>
#import <sys/stat.h>
#import <limits.h>

static pthread_mutex_t gLogLock = PTHREAD_MUTEX_INITIALIZER;
static FILE           *gLogFP = NULL;
static size_t          gLogBytes = 0;
static char            gLogPath[PATH_MAX] = {0};

// 超过这个大小就滚动一次：旧文件改名为 .1，新文件重开。
// 限大小是为了长时间挂机时不把手机存储写满。
#define PH_LOG_MAX  (2 * 1024 * 1024)   // 2MB

// ============================================================
// 日志落盘位置 —— 这里踩过一个大坑
//
// 最初固定写 /var/mobile/PhigrosAuto.log，结果文件从来不存在：
// 插件跑在游戏进程里，而游戏是受沙盒约束的 App，/var/mobile 根目录
// 对它不可写，fopen 直接返回 NULL，且不报错。表现就是"看不到日志"，
// 很容易误判成"dylib 没注入"。
//
// 正确做法是按可写性依次尝试，第一个能打开的就用它：
//   1) 自身沙盒的 Documents —— 一定有权限（rootless 越狱下路径在
//      /var/mobile/Containers/Data/Application/<UUID>/Documents/）
//   2) /var/mobile/Media/PhigrosAuto.log —— media 分区对 App 可写
//   3) /var/mobile/PhigrosAuto.log —— 越狱进程/enable 后可写
//   4) /tmp/PhigrosAuto.log —— 最后兜底
// ============================================================

// 候选路径，按可写性从高到低
static NSArray<NSString *> *PHLogCandidateList(void) {
    NSMutableArray<NSString *> *cands = [NSMutableArray array];
    // 1) 自身沙盒 Documents —— 一定有权限
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES).firstObject;
    if (docs.length) {
        [cands addObject:[docs stringByAppendingPathComponent:@"PhigrosAuto.log"]];
    }
    // 2) media 分区（App 可写）
    [cands addObject:@"/var/mobile/Media/PhigrosAuto.log"];
    // 3) 传统位置（越狱进程可写）
    [cands addObject:@"/var/mobile/PhigrosAuto.log"];
    // 4) 兜底
    [cands addObject:@"/tmp/PhigrosAuto.log"];
    return cands;
}

void PHLogInit(void) {
    pthread_mutex_lock(&gLogLock);
    if (gLogFP) { pthread_mutex_unlock(&gLogLock); return; }

    for (NSString *path in PHLogCandidateList()) {
        FILE *fp = fopen(path.UTF8String, "a");
        if (fp) {
            gLogFP = fp;
            strlcpy(gLogPath, path.UTF8String, sizeof(gLogPath));
            struct stat st;
            gLogBytes = (stat(gLogPath, &st) == 0 && st.st_size > 0)
                        ? (size_t)st.st_size : 0;
            chmod(gLogPath, 0644);   // 让 root/terminal 也能读
            break;
        }
    }

    // 一个都打不开：至少把尝试过的路径打到 console，方便从别处看到
    if (!gLogFP) {
        fprintf(stderr, "[PhigrosAuto] 所有日志路径都不可写: %s\n",
                [[PHLogCandidateList() componentsJoinedByString:@" "] UTF8String]);
    }

    pthread_mutex_unlock(&gLogLock);
}

// 供面板/诊断显示当前实际日志路径
const char *PHLogCurrentPath(void) {
    return gLogPath[0] ? gLogPath : "(未打开)";
}

void PHLogWrite(NSString *fmt, ...) {
    if (!fmt) return;

    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    if (!msg) return;

    // 时间戳用毫秒，方便对帧
    struct timeval tv;
    gettimeofday(&tv, NULL);
    struct tm tmv;
    time_t sec = tv.tv_sec;
    localtime_r(&sec, &tmv);
    char ts[32];
    snprintf(ts, sizeof(ts), "%02d:%02d:%02d.%03d",
             tmv.tm_hour, tmv.tm_min, tmv.tm_sec, (int)(tv.tv_usec / 1000));

    pthread_mutex_lock(&gLogLock);

    // 首次调用时懒初始化（constructor 可能早于文件系统就绪）
    if (!gLogFP) {
        pthread_mutex_unlock(&gLogLock);
        PHLogInit();
        pthread_mutex_lock(&gLogLock);
    }

    if (gLogFP) {
        int n = fprintf(gLogFP, "%s %s\n", ts, msg.UTF8String);
        if (n > 0) gLogBytes += (size_t)n;
        // 每行都 flush：崩溃时也能看到最后一条，代价可忽略
        fflush(gLogFP);

        if (gLogBytes > PH_LOG_MAX) {
            fclose(gLogFP);
            gLogFP = NULL;
            pthread_mutex_unlock(&gLogLock);
            PHLogInit();
            pthread_mutex_lock(&gLogLock);
        }
    }

    pthread_mutex_unlock(&gLogLock);

    NSLog(@"[PhigrosAuto] %@", msg);
}
