# 在 iPhone 15 Pro / iOS 17.1 / Relaxin 上安装 PhigrosAuto

目标设备：iPhone 15 Pro（A17 Pro），iOS 17.1，Relaxin 越狱。
打包形态：**rootless**（唯一可行形态，A17 + iOS 17 没有 rootful 方案）。

---

## 一、准备：把工程推到 GitHub

本机（`C:\Users\huang\Downloads\Deva\PhigrosAuto`）就一个普通 git 仓库：

```bash
cd PhigrosAuto
git init
git add .
git commit -m "init"
git branch -M main
git remote add origin https://github.com/[你的用户名]/PhigrosAuto.git
git push -u origin main
```

`.github/workflows/build.yml` 已经在工程里，推上去就会被 GitHub 识别。

> 仓库设成公开或私有都行。私有仓库的 artifact 只有你自己能下。

## 二、跑 Actions 出包

1. 打开仓库 → **Actions** 标签 → 左侧 `build` → 右侧 **Run workflow** → 选 `main` → 运行。
2. 等 5～10 分钟（首次要拉 Theos 和 iOS SDK，后面有缓存会快很多）。
3. 绿勾后点进这次运行，页面底部 **Artifacts** → 下载 `PhigrosAuto-rootless`。
4. 解压得到一个 `.deb`，形如 `com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb`。

如果编译红了，看日志里第一处 `error:`。最常见的两个：

| 报错 | 处理 |
|---|---|
| `dpkg-deb: command not found` | workflow 里 `brew install dpkg` 那步失败，重跑一次 |
| `il2cpp`/`substrate` 找不到头文件 | `Makefile` 的 `PhigrosAuto_LIBRARIES = substrate` 需要 ElleKit 的 compatibility 头，确认 Theos 拉的是完整仓库（`--recursive`） |

## 三、传到手机并安装

Relaxin 环境下所有系统路径都在 `/var/jb` 前缀里，dpkg 也在这个前缀下。

**方式 A：Wi-Fi 传包（推荐，能顺手看日志）**

手机和电脑连同一个 Wi-Fi。手机 IP 在 设置 → Wi-Fi → 点当前网络名 里看。

```bash
# Windows PowerShell / Git Bash 都行
scp com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb root@[IPHONE_IP]:/var/mobile/
```

Relaxin 默认 root 密码是 `alpine`，装完第一件事改掉：`passwd`。

```bash
ssh root@[IPHONE_IP]
/var/jb/usr/bin/dpkg -i /var/mobile/com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb
killall -9 SpringBoard
```

**方式 B：Sileo 本地装**

把 `.deb` 用 AirDrop / 微信文件传输 / iCloud 弄到手机上，点文件 → 用 Sileo 打开 → 安装。
Sileo 会自动按 rootless 路径解包，不用管前缀。

**方式 C：Filza**

同样传过去，Filza 里点 `.deb` → Install。

> 三条路选一条就行。装完不需要重启手机，`killall -9 SpringBoard` 重载一次桌面即可。

## 四、验证

```bash
ssh root@[IPHONE_IP]
```

先确认包真的装上了：

```bash
/var/jb/usr/bin/dpkg -l | grep phigrosauto
```

再确认插件文件到位：

```bash
ls -l /var/jb/Library/MobileSubstrate/DynamicLibraries/ | grep PhigrosAuto
```

应该看到 `PhigrosAuto.dylib` 和 `PhigrosAuto.plist` 两个文件。

然后开日志，再进游戏：

```bash
idevicesyslog | grep PhigrosAuto
```

正常的话会依次出现：

```
[PhigrosAuto] 锁定 Assets.Scripts.InGame.Judgement.JudgeManager | notes@24 time@28(float) combo@32 score@36
[PhigrosAuto] note Assets.Scripts.InGame.Notes.Note t@16(float) hold@20 x@24 type@28 done@44
[PhigrosAuto] ready — Assets.Scripts.InGame.Judgement.JudgeManager
[PhigrosAuto] ticker started @ 120 Hz
```

进游戏后左下角有个半透明圆球，点一下变绿色 `自动 ON`，开始代打。

## 五、出问题怎么查

| 现象 | 原因 | 处理 |
|---|---|---|
| 装包报 `dependency problems` | 缺 ElleKit | Sileo 里装 ElleKit（Relaxin 通常自带，确认不是被删了） |
| 圆球不出现 | 插件没被注入 | `dpkg -l` 查包、`ls` 查 dylib、确认 `PhigrosAuto.plist` 里 bundle id 是 `com.PigeonGames.Phigros` |
| 圆球出现但完全不打 | 类名候选全未命中 | 日志会打 `候选类名全部未命中`，跑 `discover.js` 补真名后重编 |
| 打歌但全是 Miss | 触点没落进游玩区 | 调 `Config.h` 的 `kTouchYRatio`（默认 0.62），每次 ±0.05 |
| 只有零星 Good | 派发延迟 | `kHitAdvance` 从 -0.004 往 -0.008 调 |
| 密集段断连击 | 按压时长太短 | `kTapHoldSeconds` 从 0.040 加到 0.055 |
| IOHID 完全没反应 | iOS 17 上客户端创建或 entitlement 问题 | 日志里会打 `IOHID 初始化失败`；确认是 rootless 注入（不是 app 内直接跑） |

## 六、iOS 17.1 特别说明

`IOHIDEventSystemClientCreate` 在 iOS 16 之后有变化，`IOHIDTouch.m` 里已经按这个顺序兜底：

1. `IOHIDEventSystemClientCreateSimpleClient(alloc, 0)` — 新变体，优先
2. `IOHIDEventSystemClientCreateWithType(alloc, 0)` — 另一种命名
3. `IOHIDEventSystemClientCreate(alloc)` — 旧签名，最后兜底

多指事件用 `IOHIDEventCreateDigitizerEvent`；如果这个符号在 17.1 上取不到，会自动退回
`IOHIDEventCreateDigitizerFingerEvent` 单指变体，功能不受影响（只是 index 靠 setInt 补）。

## 七、卸载

```bash
ssh root@[IPHONE_IP]
/var/jb/usr/bin/dpkg -r com.yg.phigrosauto
killall -9 SpringBoard
```

或 Sileo 里找到 PhigrosAuto 点卸载。
