# 装到 iPhone（全程操作手册）

设备：iPhone 15 Pro（A17 Pro）/ iOS 17.1 / Relaxin 越狱
包：`dist/com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb`（rootless，已编译签名完成）

---

## 已完成的自动化部分

GitHub Actions 已把包编译并发布，地址固定：

```
https://github.com/huhuhhuuu/PhigrosAuto/raw/main/dist/com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb
```

校验通过的项：架构 `iphoneos-arm64`、包内路径带 `/var/jb/` 前缀、`PhigrosAuto.dylib`
与 `PhigrosAuto.plist` 都在 `DynamicLibraries/` 下、dylib 含 arm64 与 arm64e 双切片。
SHA256：`88620abc3caba05add694da7f56fe3584fb86134cc936c8b5c2c85acd4dbfc16`

---

## 第一步：手机上直接下载（最快，不碰电脑）

Safari 打开上面那个链接，会提示下载。下载完在「文件」App 的「下载」里能找到
`com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb`。

然后长按该文件 → 共享 → 选 **Sileo**（或 Filza）打开 → 安装 / Install。
Sileo 会自动按 rootless 路径解包到 `/var/jb`，不需要你填任何东西。

装完下拉刷新 Sileo 的「已安装」列表，能看到 PhigrosAuto 就成了。

> 如果 Safari 直接把 .deb 显示成一堆乱码，改用在电脑上下载再传过去（见第二步）。

## 第二步：电脑传过去（能同时看日志，推荐）

手机和电脑连同一个 Wi-Fi。手机 IP：设置 → Wi-Fi → 点当前网络名 → 看「IP 地址」。

```bash
cd PhigrosAuto
./tools/deploy.sh [IPHONE_IP] dist/com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb
```

脚本会自己 ping 通、scp 传包、用 `/var/jb/usr/bin/dpkg` 装、重载 SpringBoard、
最后验证包和插件文件是否到位。root 密码默认 `alpine`。

手动做就是这几条：

```bash
scp dist/com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb root@[IPHONE_IP]:/var/mobile/
ssh root@[IPHONE_IP]
/var/jb/usr/bin/dpkg -i /var/mobile/com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb
killall -9 SpringBoard
```

## 第三步：验证插件被加载

```bash
ssh root@[IPHONE_IP]
ls -l /var/jb/Library/MobileSubstrate/DynamicLibraries/ | grep PhigrosAuto
```

必须看到两个文件：`PhigrosAuto.dylib`、`PhigrosAuto.plist`。

然后开日志，再进游戏：

```bash
idevicesyslog | grep PhigrosAuto
```

正常输出：

```
[PhigrosAuto] 锁定 <管理器类名> | notes@24 time@28(float) combo@32 score@36
[PhigrosAuto] note <音符类名> t@16(float) hold@20 x@24 type@28 done@44
[PhigrosAuto] ready — <管理器类名>
```

进游戏后左下角有个半透明圆球，点一下变绿 = 代打开启。

## 第四步：如果日志打「候选类名全部未命中」

这是唯一需要再跑一轮的情况：Phigros 当前版本的类名与我给的候选表不一致。
拿真名的流程：

```bash
cd PhigrosAuto
npm i -D frida-il2cpp-bridge frida-compile
npx frida-compile discover.js -o _discover.js
frida -U -f com.PigeonGames.Phigros -l _discover.js --no-pause
```

把打印出来的管理器类名和音符类名，加到 `Config.h` 的 `kManagerClasses` /
`kNoteClasses` 数组最前面，然后：

```bash
git add -A && git commit -m "回填真实类名" && git push
```

Actions 会自动重编，几分钟后 `dist/` 里就有新包，重复第一或第二步装一次。

## 调参（打不准时）

全在 `Config.h`，改完 push 就自动重编。

| 现象 | 改哪个 | 怎么改 |
|---|---|---|
| 全是 Miss | `kTouchYRatio` | 默认 0.62，每次 ±0.05 试 |
| 只有零星 Good | `kHitAdvance` | 从 -0.004 往 -0.008 调 |
| 密集段断连击 | `kTapHoldSeconds` | 从 0.040 加到 0.055 |
| 长条提前断 | `kHoldTailSeconds` | 从 0.020 加到 0.030 |

## 卸载

```bash
ssh root@[IPHONE_IP]
/var/jb/usr/bin/dpkg -r com.yg.phigrosauto
killall -9 SpringBoard
```

或 Sileo → 已安装 → PhigrosAuto → 卸载。
