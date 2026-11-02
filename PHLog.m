#import "PHLog.h"
#import <stdio.h>
#import <stdarg.h>
#import <unistd.h>
#import <sys/time.h>
#import <pthread.h>
#import <string.h>
#import <sys/stat.h>

static pthread_mutex_t gLogLock = PTHREAD_MUTEX_INITIALIZER;
static FILE           *gLogFP = NULL;
static size_t          gLogBytes = 0;

// 超过这个大小就滚动一次：旧文件改名为 .1，新文件重开。
// 限大小是为了长时间挂机时不把手机存储写满。
#define PH_LOG_MAX  (2 * 1024 * 1024)   // 2MB

void PHLogInit(void) {
    pthread_mutex_lock(&gLogLock);
    if (gLogFP) { pthread_mutex_unlock(&gLogLock); return; }

    // 先滚动：把上次的日志留一份
    struct stat st;
    if (stat(PH_LOG_PATH, &st) == 0 && st.st_size > (off_t)PH_LOG_MAX) {
        char bak[256];
        snprintf(bak, sizeof(bak), "%s.1", PH_LOG_PATH);
        rename(PH_LOG_PATH, bak);
    }

    gLogFP = fopen(PH_LOG_PATH, "a");
    if (gLogFP) {
        gLogBytes = (size_t)(st.st_size > 0 ? st.st_size : 0);
        // 让 mobile 用户也能读，方便 Sileo 文件管理器直接打开
        chmod(PH_LOG_PATH, 0644);
    }
    pthread_mutex_unlock(&gLogLock);
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
