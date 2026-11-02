# PhigrosAuto

Phigros iOS 越狱插件：全自动打歌（代打 + 自动判定 + 完美连击）。

不写内存、不篡改分数，全部通过系统级触点注入完成——Phigros 的判定只比较
`|noteTime - touchTime|`，与触点横向位置无关，所以在判定窗口内合成触点即可稳定拿 Perfect。

## 原理与分层

1. **IL2CPP 层**（`IL2CPP.m`）：进程内 `dlsym` 拿 Unity 导出的 `il2cpp_*` API，按类名找
   `JudgeManager`，按字段名解析偏移。所有名字都走候选列表，不硬编码偏移，换版本也能自愈。
2. **注入层**（`IOHIDTouch.m`）：`IOHIDEventCreateDigitizerEvent` + `IOHIDEventSystemClientDispatchEvent`
   合成多点触点，绕过 UIKit 手势层，120Hz 下每帧只推一个事件，抖动 1~2ms。
3. **调度层**（`Autoplay.m`）：每帧读在谱音符，`now >= noteTime` 即落指；长条按住到
   `noteTime + holdTime`；flick 在松开前补一次上划位移。已按音符用指针集合记账，不会重复触发。
4. **驱动层**（`Tweak.xm`）：`CADisplayLink` 跟随 ProMotion，悬浮按钮开关 + 长按开日志。

## 构建

## 构建（GitHub Actions，推荐）

`.github/workflows/build.yml` 已带好 rootless 打包。推到仓库 → Actions 里跑 `build` → 下载
`PhigrosAuto-rootless` artifact，里面就是 rootless 的 `.deb`。

本机编译的话：

```bash
export THEOS=~/theos
cd PhigrosAuto
make package THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1
```

## 目标环境

iOS 17.1 / iPhone 15 Pro（A17 Pro），Relaxin 越狱。这条路只有 rootless 一种形态：
包架构 `iphoneos-arm64`、装到 `/var/jb`、dpkg 走 `/var/jb/usr/bin/dpkg`。
`Makefile` 里 SDK 门槛写的 15.0，17.x SDK 编译无碍。

Relaxin 自带 bootstrap 与 ElleKit，插件加载路径是
`/var/jb/Library/MobileSubstrate/DynamicLibraries/`。装完 `dpkg -l | grep phigrosauto`
能看到包、但游戏里没反应时，先确认 ElleKit 在 Sileo 里是已安装状态。

## 第一次运行（关键）

插件装好后进游戏，日志里会打印命中的组合。用 `idevicesyslog | grep PhigrosAuto` 看：

```
[PhigrosAuto] 锁定 Assets.Scripts.InGame.Judgement.JudgeManager |
              notes@24 time@28(float) combo@32 score@36
[PhigrosAuto] note Assets.Scripts.InGame.Notes.Note t@16(float) hold@20 x@24 type@28 done@44
[PhigrosAuto] ready — Assets.Scripts.InGame.Judgement.JudgeManager
```

字段后括号里的 `float`/`double` 来自 il2cpp 元数据的字段类型名，不是猜的。
如果只看到 `候选类名全部未命中`，说明类名与这份候选表不符，跑侦察脚本取真名：

```bash
npm i -D frida-il2cpp-bridge frida-compile
npx frida-compile discover.js -o _discover.js
frida -U -f com.PigeonGames.Phigros -l _discover.js --no-pause
```

脚本会打印：

- 所有类名匹配 `Judge|Note|Chart|Score` 的类 + 完整字段表 + 方法签名
- `NoteType` 枚举的真实序号（Tap/Drag/Hold/Flick 的顺序决定 `Config.h` 里 `kNoteTypeFlick`）
- 管理器实例的实时 `time` 与音符表前三个音符的 `time`

把真实名字补到 `Config.h` 对应候选数组的**最前面**（保留原有候选作为后备），重编译即可。

## 校准

落点只影响视觉和多指区分，不影响判定。但要让触点落在游玩区内、且不压到暂停热区：

| 参数 | 默认 | 调整依据 |
|---|---|---|
| `kTouchYRatio` | 0.62 | 屏幕高度比例。被判为"点空了"就往上/下移 0.05 试 |
| `kPlayfieldWidth` | 1.0 | `positionX` 是 0~1 归一化时保持 1.0；若是像素值改成实际宽度 |
| `kHitAdvance` | -0.004 | 出现 Good 说明偏晚，往更负调（-0.008）；出现 Bad 反方向 |
| `kTapHoldSeconds` | 0.040 | 连击断在密集段就加大到 0.055 |
| `kHoldTailSeconds` | 0.020 | 长条末尾掉判定就加大 |
| `kTickRateCap` | 0 | 想省电设 60，但密集段建议保持 120 |

观察手段：长按悬浮球开 verbose，日志会打每一刀的 `t / now / hold / slot / x`。
`now - t` 稳定在 0 附近即对齐；若整段恒定偏移，直接改 `kHitAdvance` 或校时间字段。

## 判定保险（可选）

纯触点方案在 120Hz 下通常不需要兜底。若某些机型掉帧导致零星 Good，可在
`discover.js` 里确认判定方法签名后加一层结果改写。先取签名：

```
=== Assets.Scripts.InGame.Judgement.JudgeManager ===
  [methods]
    System.Void Judge(Note, System.Single)
    System.Void Judge(Note, System.Single, System.Int32)
```

拿到参数个数后，用同样的 IL2CPP 解析 + `MSHookFunction` 挂钩方法指针，把判定结果参数钳到
Perfect 分支。注意这类改写会让客户端状态与服务端校验出现偏差，建议只在小号上用。
默认工程**不启用**这层，`Tweak.xm` 未包含任何内存写入。

## 已知不确定项

| 项 | 状态 |
|---|---|
| 管理器/音符类名 | 候选表 + 运行时探测；补真名后即稳定 |
| `time` 字段 float/double | 运行时按取值合理性自动判定，日志会写明 |
| `NoteType` 枚举序 | 默认 Tap=0 Drag=1 Hold=2 Flick=3；discover.js 可打印真实值 |
| 长条结束时刻 | 优先用 `holdTime` 字段；若该字段是"结束时间"而非时长，把 `kHoldTailSeconds` 设为负值补偿 |

## 故障排查

| 现象 | 原因与处理 |
|---|---|
| 悬浮球出现但不打歌 | 类名未命中，看日志是否 `全部未命中`，跑 discover.js |
| 打歌但全是 Miss | 触点没落进游玩区，调 `kTouchYRatio`；或 `now` 与音符时间基准不同（时间字段选错，换 `kTimeFields` 候选） |
| 只有第一段能打，之后全断 | 换曲检测过于激进，看日志 `chart changed`；确认后清掉 `hugeShift` 分支 |
| 长条只吃到头 | `holdTime` 语义不同，见上表 |
| 触点完全不生成 | IOKit 私有框架路径不对，`PHTouchInit` 返回 NO；确认 `/System/Library/PrivateFrameworks/IOKit.framework/IOKit` 存在 |
