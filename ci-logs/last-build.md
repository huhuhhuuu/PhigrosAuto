# build log 2026-11-02T17:37:14Z

## make package
```
[0;36m==> [1;36mNotice:[m Build may be slow as Theos isn’t using all available CPU cores on this computer. Consider upgrading GNU Make: https://theos.dev/docs/parallel-building
[1;31m> [1;3;39mMaking all for tweak PhigrosAuto…[m
[0;32m==> [1;39mCompiling Tweak.m (arm64)…[m
[0;32m==> [1;39mCompiling IL2CPP.m (arm64)…[m
[0;32m==> [1;39mCompiling IOHIDTouch.m (arm64)…[m
[0;32m==> [1;39mCompiling NoteModel.m (arm64)…[m
[0;32m==> [1;39mCompiling Autoplay.m (arm64)…[m
[0;32m==> [1;39mCompiling PHLog.m (arm64)…[m
[0;33m==> [1;39mLinking tweak PhigrosAuto (arm64)…[m
ld: warning: -multiply_defined is obsolete
[0;34m==> [1;39mGenerating debug symbols for PhigrosAuto…[m
[0;34m==> [1;39mStripping PhigrosAuto (arm64)…[m
[0;32m==> [1;39mCompiling Tweak.m (arm64e)…[m
[0;32m==> [1;39mCompiling IL2CPP.m (arm64e)…[m
[0;32m==> [1;39mCompiling IOHIDTouch.m (arm64e)…[m
[0;32m==> [1;39mCompiling NoteModel.m (arm64e)…[m
[0;32m==> [1;39mCompiling Autoplay.m (arm64e)…[m
[0;32m==> [1;39mCompiling PHLog.m (arm64e)…[m
[0;33m==> [1;39mLinking tweak PhigrosAuto (arm64e)…[m
ld: warning: -multiply_defined is obsolete
[0;34m==> [1;39mGenerating debug symbols for PhigrosAuto…[m
[0;34m==> [1;39mStripping PhigrosAuto (arm64e)…[m
[0;34m==> [1;39mMerging tweak PhigrosAuto…[m
[0;34m==> [1;39mSigning PhigrosAuto…[m
[1;31m> [1;3;39mMaking stage for tweak PhigrosAuto…[m
dm.pl: building package `com.yg.phigrosauto:iphoneos-arm64' in `./packages/com.yg.phigrosauto_1.7.0_iphoneos-arm64.deb'
```

## package
```
=== ls packages ===
total 48
-rw-r--r--  1 runner  staff    24K Nov  2 17:37 com.yg.phigrosauto_1.7.0_iphoneos-arm64.deb
DEB=packages/com.yg.phigrosauto_1.7.0_iphoneos-arm64.deb
=== dpkg-deb -I ===
 new Debian package, version 2.0.
 size 24506 bytes: control archive=349 bytes.
     255 bytes,    10 lines      control
 Package: com.yg.phigrosauto
 Name: PhigrosAuto
 Description: Phigros 全自动打歌 — 代打 / 自动判定 / 完美连击
 Maintainer: YG
 Author: YG
 Section: Tweaks
 Depends: mobilesubstrate
 Architecture: iphoneos-arm64
 Version: 1.7.0
 Installed-Size: 216
=== dpkg-deb -c ===
drwxr-xr-x root/wheel        0 2026-11-02 17:37 .
drwxr-xr-x root/wheel        0 2026-11-02 17:37 var
drwxr-xr-x root/wheel        0 2026-11-02 17:37 var/jb
drwxr-xr-x root/wheel        0 2026-11-02 17:37 var/jb/Library
drwxr-xr-x root/wheel        0 2026-11-02 17:37 var/jb/Library/MobileSubstrate
drwxr-xr-x root/wheel        0 2026-11-02 17:37 var/jb/Library/MobileSubstrate/DynamicLibraries
-rwxr-xr-x root/wheel   206768 2026-11-02 17:37 var/jb/Library/MobileSubstrate/DynamicLibraries/PhigrosAuto.dylib
-rw-r--r-- root/wheel       95 2026-11-02 17:37 var/jb/Library/MobileSubstrate/DynamicLibraries/PhigrosAuto.plist
drwxr-xr-x root/wheel        0 2026-11-02 17:36 var/jb/usr
drwxr-xr-x root/wheel        0 2026-11-02 17:36 var/jb/usr/bin
-rwxr-xr-x root/wheel     8144 2026-11-02 17:36 var/jb/usr/bin/phprobe
```

## verify
```
Architecture: iphoneos-arm64
OK   Architecture=iphoneos-arm64
WARN 包内含 /var/jb/ 前缀
OK   含 PhigrosAuto.dylib
OK   含 PhigrosAuto.plist
extract rc=0
-rwxr-xr-x  1 runner  wheel  8144 Nov  2 17:36 /tmp/debx/var/jb/usr/bin/phprobe
-rwxr-xr-x  1 runner  wheel  206768 Nov  2 17:37 /tmp/debx/var/jb/Library/MobileSubstrate/DynamicLibraries/PhigrosAuto.dylib
-rw-r--r--  1 runner  wheel  95 Nov  2 17:37 /tmp/debx/var/jb/Library/MobileSubstrate/DynamicLibraries/PhigrosAuto.plist
dylib archs: arm64 arm64e
OK   dylib 含 arm64e 切片
OK   control 无重复字段
--- verify result: FAIL=1 ---
```
