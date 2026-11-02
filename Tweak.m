#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "Config.h"
#import "IL2CPP.h"
#import "NoteModel.h"
#import "Autoplay.h"
#import "IOHIDTouch.h"

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
    NSLog(@"[PhigrosAuto] ticker started @ %ld Hz", (long)gTicker.link.preferredFramesPerSecond);
}

// ============================================================
// 悬浮开关：可拖动，点按切换代打，长按切换 verbose 日志
// ============================================================

@interface PHPanel : UIWindow
@property (nonatomic, strong) UIButton *btn;
- (void)show;
- (void)refresh;
@end

@implementation PHPanel

- (instancetype)init {
    CGRect r = CGRectMake(24, 180, 64, 64);
    self = [super initWithFrame:r];
    if (!self) return nil;

    self.windowLevel = UIWindowLevelAlert + 100;
    self.backgroundColor = [UIColor clearColor];
    self.rootViewController = [UIViewController new];

    _btn = [UIButton buttonWithType:UIButtonTypeCustom];
    _btn.frame = self.bounds;
    _btn.layer.cornerRadius = 32;
    _btn.layer.masksToBounds = YES;
    _btn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    _btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    _btn.titleLabel.numberOfLines = 2;
    [_btn setTitle:@"自动\nOFF" forState:UIControlStateNormal];
    [_btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    [_btn addTarget:self action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    [_btn addGestureRecognizer:lp];
    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
    [_btn addGestureRecognizer:pan];

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
}

- (void)onTap {
    BOOL on = !PHAutoplayIsEnabled();
    PHAutoplaySetEnabled(on);
    [self refresh];
}

- (void)refresh {
    BOOL on = PHAutoplayIsEnabled();
    [_btn setTitle:(on ? @"自动\nON" : @"自动\nOFF") forState:UIControlStateNormal];
    _btn.backgroundColor = on ? [UIColor colorWithRed:0.10 green:0.62 blue:0.35 alpha:0.75]
                              : [UIColor colorWithWhite:0.0 alpha:0.45];
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

// 等游戏场景起来：每 0.5s 试一次，最多 60s。
// 用静态函数递归而不是自捕获 block，避免 ARC 下的 retain cycle。
static void PHPollScene(void) {
    if (PHModelResolve()) {
        PHStartTicker();
        NSLog(@"[PhigrosAuto] ready — %s", PHModelShared()->managerName);
        return;
    }
    if (++gBootTries > 120) {
        NSLog(@"[PhigrosAuto] 放弃探测，跑 discover.js 取真实类名");
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        PHPollScene();
    });
}

static void PHBootstrap(void) {
    if (!PHL2CPPInit()) {
        NSLog(@"[PhigrosAuto] il2cpp 绑定失败，检查 UnityFramework 是否已加载");
        return;
    }
    PHTouchInit();

    PHPollScene();

    if (!gPanel) {
        gPanel = [[PHPanel alloc] init];
        [gPanel show];
        [gPanel refresh];
    }
}

__attribute__((constructor))
static void PHInit(void) {
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
