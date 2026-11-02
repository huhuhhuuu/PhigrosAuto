#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <unistd.h>
#import "Config.h"
#import "IL2CPP.h"
#import "NoteModel.h"
#import "Autoplay.h"
#import "IOHIDTouch.h"
#import "PHLog.h"

// ============================================================
// 驱动层：CADisplayLink 跟随屏幕刷新（ProMotion 上就是 120Hz）
// 游戏逻辑本身在 Unity 主线程，我们在主线程同帧读取，读到的音符状态是一致的。
// ============================================================

@interface PHTicker : NSObject
@property (nonatomic, strong) CADisplayLink *link;
@end

@implementation PHTicker
- (void)tick:(CADisplayLink *)l {
    PHAutoplayTick();
}
@end

static PHTicker *gTicker;

static void PHStartTicker(void) {
    if (gTicker) return;
    gTicker = [PHTicker new];
    gTicker.link = [CADisplayLink displayLinkWithTarget:gTicker selector:@selector(tick:)];
    // 0 = 跟随屏幕；想限帧可设成 1/60
    if (kTickRateCap > 0) gTicker.link.preferredFramesPerSecond = kTickRateCap;
    [gTicker.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    PHLogWrite(@"ticker started @ %ld Hz", (long)gTicker.link.preferredFramesPerSecond);
}

// ============================================================
// 悬浮开关
//   点按     —— 切换代打
//   长按     —— 切换 verbose 日志
//   双击     —— 展开/收起状态文本（看类名命中情况）
//   拖动     —— 移动
//
// 面板在 il2cpp 失败时也会显示，标题直接写明失败原因。
// 这样"看不到按钮"这件事本身就不会再发生——看不到就是没注入。
// ============================================================

typedef NS_ENUM(NSInteger, PHState) {
    PHStateBooting = 0,   // 正在等游戏场景
    PHStateReady,         // 已就绪，可以代打
    PHStateNoIl2CPP,      // il2cpp 符号没绑上
    PHStateNoClass,       // 类名全部未命中
    PHStateTimeout,       // 探测超时
};

@interface PHPanel : NSObject
@property (nonatomic, strong) UIButton *btn;
@property (nonatomic, strong) UILabel  *info;
@property (nonatomic, assign) PHState   state;
@property (nonatomic, assign) BOOL      expanded;
@property (nonatomic, weak)   UIWindow *hostWindow;
- (void)show;
- (void)refresh;
- (void)setState:(PHState)s detail:(NSString *)detail;
- (BOOL)attachSceneIfNeeded;
- (void)makeReal;
- (void)retryShow;
@end

@implementation PHPanel

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    self.state = PHStateBooting;

    _btn = [UIButton buttonWithType:UIButtonTypeCustom];
    _btn.frame = CGRectMake(24, 180, 64, 64);
    _btn.layer.cornerRadius = 32;
    _btn.layer.masksToBounds = YES;
    _btn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    _btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    _btn.titleLabel.numberOfLines = 3;
    _btn.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_btn setTitle:@"等待\n场景" forState:UIControlStateNormal];
    [_btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    [_btn addGestureRecognizer:lp];
    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
    [_btn addGestureRecognizer:pan];
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
    [_btn addGestureRecognizer:tap];
    UITapGestureRecognizer *dbl =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap)];
    dbl.numberOfTapsRequired = 2;
    // 单击等双击判定失败才触发，避免一次点按被两个手势都吃掉
    [tap requireGestureRecognizerToFail:dbl];
    [_btn addGestureRecognizer:dbl];

    return self;
}

// ============================================================
// 挂载策略（曾在这里踩过大坑）
//
// 最初用自建 UIWindow 当 overlay，在 Unity 应用里几乎必然失败：
//   · iOS 13+ 自建 UIWindow 必须挂到 ForegroundActive 的 UIWindowScene，
//     否则 hidden=NO 也不会显示；
//   · Unity 的 CAMetalLayer 高刷渲染常常盖住外部 window；
//   · 注入发生在 constructor，那时连 windowScene 都还没有。
//
// 改为：直接找游戏自己的 keyWindow，把按钮 addSubview 上去。
// 这样不依赖自建 window 的生命周期，跟游戏 UI 同一个图层栈，
// 一定画得出来。windowScene 只作为最后的兜底。
// ============================================================

// 找当前最靠前的可见 window
static UIWindow *PHFindHostWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (!app) return nil;

    // 1) 优先 keyWindow（iOS 15+ 走 windowScene.keyWindow）
    for (UIScene *sc in app.connectedScenes) {
        if (![sc isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)sc;
        if (ws.activationState != UISceneActivationStateForegroundActive) continue;
        if (@available(iOS 15.0, *)) {
            if (ws.keyWindow) return ws.keyWindow;
        }
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) return w;
        }
    }

    // 2) 退回各 scene 的 windows 里层级最高的可见 window
    //    注意不能直接用 UIApplication 上的 windows 属性：iOS 15 起它被
    //    标记 deprecated，而工程开了 -Werror，deprecated 直接算编译失败。
    UIWindow *best = nil;
    NSMutableArray<UIWindow *> *all = [NSMutableArray array];
    for (UIScene *sc in app.connectedScenes) {
        if (![sc isKindOfClass:[UIWindowScene class]]) continue;
        [all addObjectsFromArray:((UIWindowScene *)sc).windows];
    }
    for (UIWindow *w in all) {
        if (w.hidden || w.alpha < 0.01) continue;
        if (!best || w.windowLevel >= best.windowLevel) best = w;
    }
    if (best) return best;

    // 3) 兜底：任何 window 都行
    return all.firstObject;
}

- (BOOL)attachSceneIfNeeded {
    return PHFindHostWindow() != nil;
}

- (void)show {
    [self makeReal];
    if (!self.hostWindow) {
        [self retryShow];
    }
}

- (void)makeReal {
    UIWindow *host = PHFindHostWindow();
    if (!host) {
        PHLogWrite(@"panel: 还没有可用 window，稍后重试");
        return;
    }

    // 已经挂在这个 window 上就不用重复加
    if (self.hostWindow == host && self.btn.superview == host) {
        self.btn.hidden = NO;
        [host bringSubviewToFront:self.btn];
        [self refresh];
        return;
    }

    [self.btn removeFromSuperview];
    self.hostWindow = host;
    [host addSubview:self.btn];
    [host bringSubviewToFront:self.btn];
    self.btn.hidden = NO;
    [self refresh];

    PHLogWrite(@"panel 已挂到 keyWindow (level=%.0f, %gx%g)",
              host.windowLevel, host.bounds.size.width, host.bounds.size.height);
}

- (void)retryShow {
    static int tries = 0;
    if (tries > 240) {   // 60 秒
        PHLogWrite(@"panel 挂载失败（重试 %d 次仍无 window）", tries);
        return;
    }
    tries++;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) s = weakSelf;
        if (!s) return;
        [s makeReal];
        if (!s.hostWindow) [s retryShow];
    });
}

- (void)onTap {
    // 没就绪时点按只刷新状态，不假装能开打
    if (self.state != PHStateReady) {
        [self refresh];
        return;
    }
    BOOL on = !PHAutoplayIsEnabled();
    PHAutoplaySetEnabled(on);
    [self refresh];
}

- (void)onDoubleTap {
    self.expanded = !self.expanded;
    [self refresh];
}

- (void)refresh {
    NSString *title = nil;
    UIColor  *bg    = nil;

    switch (self.state) {
        case PHStateReady: {
            BOOL on = PHAutoplayIsEnabled();
            title = on ? @"自动\nON" : @"自动\nOFF";
            bg = on ? [UIColor colorWithRed:0.10 green:0.62 blue:0.35 alpha:0.78]
                    : [UIColor colorWithWhite:0.0 alpha:0.45];
            break;
        }
        case PHStateNoIl2CPP:
            title = @"il2cpp\n失败"; bg = [UIColor colorWithRed:0.72 green:0.16 blue:0.16 alpha:0.80];
            break;
        case PHStateNoClass:
            title = @"类名\n未命中"; bg = [UIColor colorWithRed:0.78 green:0.42 blue:0.05 alpha:0.80];
            break;
        case PHStateTimeout:
            title = @"探测\n超时"; bg = [UIColor colorWithRed:0.55 green:0.35 blue:0.05 alpha:0.80];
            break;
        default:
            title = @"等待\n场景"; bg = [UIColor colorWithWhite:0.15 alpha:0.55];
            break;
    }
    [_btn setTitle:title forState:UIControlStateNormal];
    _btn.backgroundColor = bg;

    if (self.expanded) {
        PHModel *m = PHModelShared();
        NSString *detail = m->managerName[0] ? [NSString stringWithUTF8String:m->managerName] : @"—";
        [_btn setTitle:[NSString stringWithFormat:@"%@\n%@", title, detail]
             forState:UIControlStateNormal];
        _btn.titleLabel.font = [UIFont systemFontOfSize:10];
    } else {
        _btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    }
}

- (void)setState:(PHState)s detail:(NSString *)detail {
    self.state = s;
    [self refresh];
    if (detail.length) PHLogWrite(@"state -> %ld: %@", (long)s, detail);
}

- (void)onLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    static BOOL verbose = NO;
    verbose = !verbose;
    PHAutoplaySetVerbose(verbose);
    [_btn setTitle:(verbose ? @"日志\nON" : @"日志\nOFF") forState:UIControlStateNormal];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self refresh]; });
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    UIView *v = self.btn;
    CGPoint d = [g translationInView:v.superview];
    CGPoint c = v.center;
    c.x += d.x; c.y += d.y;
    // 夹在屏幕内，避免拖出可视区后再也点不到
    CGRect sb = [UIScreen mainScreen].bounds;
    c.x = MAX(40, MIN(sb.size.width - 40, c.x));
    c.y = MAX(60, MIN(sb.size.height - 40, c.y));
    v.center = c;
    [g setTranslation:CGPointZero inView:v.superview];
}
@end

static PHPanel *gPanel;
static int gBootTries = 0;

// ============================================================
// 入口
// ============================================================

// 面板必须最先建：哪怕后面全挂，用户也能看到面板上写的失败原因。
static void PHEnsurePanel(void) {
    if (gPanel) return;
    gPanel = [[PHPanel alloc] init];
    [gPanel show];
}

// Unity 生命周期里 key window 可能被替换（场景切换、横竖屏重建），
// 按钮会因为宿主 window 被销毁而一起消失。这里定期核对一次，
// 发现按钮已不在任何 window 上就重新挂。
static void PHKeepPanelAlive(void) {
    if (!gPanel) return;
    UIWindow *host = PHFindHostWindow();
    if (host && gPanel.btn.superview != host) {
        [gPanel makeReal];
    } else if (host) {
        [host bringSubviewToFront:gPanel.btn];
    }
}

// 慢速轮询：只在还没解析出管理器时用，进到游玩界面就会命中
static void PHPollSceneSlow(void);

// 等游戏场景起来：每 0.5s 试一次。
// 用静态函数递归而不是自捕获 block，避免 ARC 下的 retain cycle。
static void PHPollScene(void) {
    if (PHModelResolve()) {
        PHStartTicker();
        PHModel *m = PHModelShared();
        PHLogWrite(@"ready — %s", m->managerName);
        [gPanel setState:PHStateReady detail:[NSString stringWithUTF8String:m->managerName]];
        return;
    }
    if (++gBootTries > 120) {
        // Unity 启动慢 / 还在加载页面时不要彻底放弃：降频继续等，
        // 否则"进游戏晚了一点"会永久性地变成"插件没反应"。
        PHLogWrite(@"60s 未命中候选类名，降频继续（每 2s 一次）");
        [gPanel setState:PHStateNoClass detail:@"未命中候选类名，仍在等待"];
        gBootTries = 0;   // 重新计数，下面走慢速轮询
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            PHPollSceneSlow();
        });
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        PHPollScene();
    });
}

// 慢速轮询：只在还没解析出管理器时用，进到游玩界面就会命中
static void PHPollSceneSlow(void) {
    if (PHModelResolve()) {
        PHStartTicker();
        PHModel *m = PHModelShared();
        PHLogWrite(@"ready — %s", m->managerName);
        [gPanel setState:PHStateReady detail:[NSString stringWithUTF8String:m->managerName]];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        PHPollSceneSlow();
    });
}

// 绑不到 il2cpp 时不放弃：UnityFramework 是游戏启动后才 dlopen 的，
// 早绑定必然失败，必须持续重试直到它出现。
static void PHWaitForIl2CPP(int attempt) {
    if (PHL2CPPInit()) {
        PHLogWrite(@"il2cpp 绑定成功（第 %d 次尝试）%s", attempt, PHL2CPPDiagnose());
        PHTouchInit();
        [gPanel setState:PHStateBooting detail:@"开始探测谱面管理器"];
        PHPollScene();
        return;
    }
    if (attempt == 1 || attempt % 10 == 0) {
        PHLogWrite(@"il2cpp 尚未就绪（第 %d 次）%s", attempt, PHL2CPPDiagnose());
    }
    // 前 20 次 0.25s 一次（启动阶段），之后 1s 一次
    double delay = attempt < 20 ? 0.25 : 1.0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        PHWaitForIl2CPP(attempt + 1);
    });
}

static void PHBootstrap(void) {
    PHLogWrite(@"bootstrap start %s", PHL2CPPDiagnose());

    // 面板先出来，再谈能不能干活。
    // 面板本身不依赖 il2cpp，必须无条件显示 —— 否则"看不到球"
    // 就分不清是没注入还是 il2cpp 没绑上。
    PHEnsurePanel();

    // 每 0.5s 核对一次面板是否还在宿主 window 上
    static dispatch_source_t keepTimer = nil;
    if (!keepTimer) {
        keepTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                           dispatch_get_main_queue());
        dispatch_source_set_timer(keepTimer,
                                  dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                                  (uint64_t)(0.5 * NSEC_PER_SEC),
                                  (uint64_t)(0.05 * NSEC_PER_SEC));
        dispatch_source_set_event_handler(keepTimer, ^{
            PHKeepPanelAlive();
        });
        dispatch_resume(keepTimer);
    }

    PHWaitForIl2CPP(1);
}

__attribute__((constructor))
static void PHInit(void) {
    // 第一件事：写心跳。不用日志框架，不依赖任何 UI/il2cpp 状态。
    // 这个文件一旦出现，就证明注入成功，后面所有排查都不必再怀疑注入。
    PHWriteHeartbeat("constructor");

    PHLogInit();
    PHWriteHeartbeat("log-init");
    PHLogWrite(@"==== dylib 已注入 (pid %d) ====", (int)getpid());
    PHLogWrite(@"日志实际写入: %s", PHLogCurrentPath());

    // 主线程装配 UI 与 CADisplayLink
    dispatch_async(dispatch_get_main_queue(), ^{
        // 延迟一拍，让 UnityFramework 完成首次加载与 il2cpp 初始化
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            PHBootstrap();
        });
    });

    // 应用退到后台时把触点全部抬起，避免残留按下状态
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *n) {
        PHAutoplayReset();
    }];
}
