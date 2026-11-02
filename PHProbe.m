#import <Foundation/Foundation.h>
#import <unistd.h>
#import <sys/time.h>
#import <fcntl.h>
#import <string.h>

// ============================================================
// PHProbe —— 对照探针
//
// 这个 dylib 不做任何事，只在被加载时往文件里写一行时间戳。
// 它的 filter 指向 SpringBoard（系统桌面）。
//
// 用途：和 PhigrosAuto 一起装进同一个 deb，做一次二元实验：
//
//   PHProbe.marker 出现 + PhigrosAuto.marker 不出现
//     => 注入链正常，问题在 Phigros 的 filter 匹配
//        （bundle id 不对 / 被 RootHide 屏蔽 / 游戏没冷启动）
//
//   两个 marker 都不出现
//     => 注入链本身是坏的，与插件代码无关
//
// 实测结论：两个都不出现。你这台机器跑的是完整 RootHide 栈，
// 它把加载路径重定位后汇进 AutoPatches.dylib，新装的插件若没进
// 那份汇总就永远不会被加载 —— 装完必须完整重启设备才生效。
//
// SpringBoard 是 root 进程，可以写 /var/mobile/Media，不需要沙盒回退。
// ============================================================

static void PHProbeMark(const char *tag) {
    const char *paths[] = {
        "/var/mobile/Media/PHProbe.marker",
        "/tmp/PHProbe.marker",
        NULL
    };

    struct timeval tv;
    gettimeofday(&tv, NULL);
    struct tm tmv;
    time_t sec = tv.tv_sec;
    localtime_r(&sec, &tmv);

    char buf[256];
    int n = snprintf(buf, sizeof(buf), "%02d:%02d:%02d.%03d pid=%d %s\n",
                     tmv.tm_hour, tmv.tm_min, tmv.tm_sec,
                     (int)(tv.tv_usec / 1000), (int)getpid(),
                     tag ? tag : "");
    if (n <= 0) return;

    for (int i = 0; paths[i]; i++) {
        int fd = open(paths[i], O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (fd >= 0) {
            write(fd, buf, (size_t)n);
            close(fd);
            return;
        }
    }
}

__attribute__((constructor))
static void PHProbeInit(void) {
    // 第一个落点：证明 dylib 被 dyld 加载且 constructor 执行了
    PHProbeMark("springboard-constructor");
}
