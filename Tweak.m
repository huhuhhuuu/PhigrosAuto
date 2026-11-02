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

@interface PHPanel : UIWindow
@property (nonatomic, strong) UIButton *btn;
@property (nonatomic, strong) UILabel  *info;
@property (nonatomic, assign) PHState   state;
@property (nonatomic, assign) BOOL      expanded;
- (void)show;
- (void)refresh;
- (void)setState:(PHState)s detail:(NSString *)detail;
@end

@implementation PHPanel

- (instancetype)init {
    CGRect r = CGRectMake(24, 180, 64, 64);
    self = [super initWithFrame:r];
    if (!self) return nil;

    self.windowLevel = UIWindowLevelAlert + 100;
    self.backgroundColor = [UIColor clearColor];
    self.rootViewController = [UIViewController new];
    self.state = PHStateBooting;

    _btn = [UIButton buttonWithType:UIButtonTypeCustom];
    _btn.frame = self.bounds;
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

    [self.rootViewController.view addSubview:_btn];
    return self;
}

// iOS 13+ 的 overlay window 必须挂到 windowScene 才会真正显示
- (void)show {
    if (@available(iOS 13.0, *)) {
        if (!self.windowScene) {
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] &&
                    s.activationState == UISceneActivationStateForegroundActive) {
                    self.windowScene = (UIWindowScene *)s;
                    break;
                }
            }
        }
    }
    self.hidden = NO;
    [self refresh];
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
    CGPoint d = [g translationInView:self];
    CGPoint c = self.center;
    c.x += d.x; c.y += d.y;
    // 夹在屏幕内，避免拖出可视区后再也点不到
    CGRect sb = [UIScreen mainScreen].bounds;
    c.x = MAX(40, MIN(sb.size.width - 40, c.x));
    c.y = MAX(60, MIN(sb.size.height - 40, c.y));
    self.center = c;
    [g setTranslation:CGPointZero inView:self];
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

// 等游戏场景起来：每 0.5s 试一次，最多 60s。
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
        PHLogWrite(@"放弃探测，跑 discover.js 取真实类名");
        [gPanel setState:PHStateNoClass detail:@"探测 60s 未命中候选类名"];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        PHPollScene();
    });
}

static void PHBootstrap(void) {
    PHLogWrite(@"bootstrap start");

    // 面板先出来，再谈能不能干活
    PHEnsurePanel();

    if (!PHL2CPPInit()) {
        PHLogWrite(@"il2cpp 绑定失败，检查 UnityFramework 是否已加载");
        [gPanel setState:PHStateNoIl2CPP detail:@"dlsym 拿不到 il2cpp 符号"];
        return;
    }
    PHLogWrite(@"il2cpp 绑定成功");
    PHTouchInit();

    [gPanel setState:PHStateBooting detail:@"开始探测谱面管理器"];
    PHPollScene();
}

__attribute__((constructor))
static void PHInit(void) {
    PHLogInit();
    PHLogWrite(@"==== dylib 已注入 (pid %d) ====", (int)getpid());

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
