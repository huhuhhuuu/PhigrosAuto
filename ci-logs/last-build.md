# build log 2026-11-02T18:03:14Z

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
[1;31m> [1;3;39mMaking all for tweak PHProbe…[m
[0;32m==> [1;39mCompiling PHProbe.m (arm64)…[m
[0;33m==> [1;39mLinking tweak PHProbe (arm64)…[m
ld: warning: -multiply_defined is obsolete
[0;34m==> [1;39mGenerating debug symbols for PHProbe…[m
[0;34m==> [1;39mStripping PHProbe (arm64)…[m
[0;32m==> [1;39mCompiling PHProbe.m (arm64e)…[m
[0;33m==> [1;39mLinking tweak PHProbe (arm64e)…[m
ld: warning: -multiply_defined is obsolete
[0;34m==> [1;39mGenerating debug symbols for PHProbe…[m
[0;34m==> [1;39mStripping PHProbe (arm64e)…[m
[0;34m==> [1;39mMerging tweak PHProbe…[m
[0;34m==> [1;39mSigning PHProbe…[m
[1;31m> [1;3;39mMaking stage for tweak PhigrosAuto…[m
[1;31m> [1;3;39mMaking stage for tweak PHProbe…[m
dm.pl: building package `com.yg.phigrosauto:iphoneos-arm64' in `./packages/com.yg.phigrosauto_1.10.0_iphoneos-arm64.deb'
```

## package
```
=== ls packages ===
total 56
-rw-r--r--  1 runner  staff    27K Nov  2 18:03 com.yg.phigrosauto_1.10.0_iphoneos-arm64.deb
DEB=packages/com.yg.phigrosauto_1.10.0_iphoneos-arm64.deb
=== dpkg-deb -I ===
 new Debian package, version 2.0.
 size 27652 bytes: control archive=347 bytes.
     256 bytes,    10 lines      control
 Package: com.yg.phigrosauto
 Name: PhigrosAuto
 Description: Phigros 全自动打歌 — 代打 / 自动判定 / 完美连击
 Maintainer: YG
 Author: YG
 Section: Tweaks
 Depends: mobilesubstrate
 Architecture: iphoneos-arm64
 Version: 1.10.0
 Installed-Size: 364
=== dpkg-deb -c ===
drwxr-xr-x root/wheel        0 2026-11-02 18:03 .
drwxr-xr-x root/wheel        0 2026-11-02 18:03 var
drwxr-xr-x root/wheel        0 2026-11-02 18:03 var/jb
drwxr-xr-x root/wheel        0 2026-11-02 18:03 var/jb/Library
drwxr-xr-x root/wheel        0 2026-11-02 18:03 var/jb/Library/MobileSubstrate
drwxr-xr-x root/wheel        0 2026-11-02 18:03 var/jb/Library/MobileSubstrate/DynamicLibraries
-rwxr-xr-x root/wheel   132880 2026-11-02 18:03 var/jb/Library/MobileSubstrate/DynamicLibraries/PHProbe.dylib
-rw-r--r-- root/wheel       93 2026-11-02 18:03 var/jb/Library/MobileSubstrate/DynamicLibraries/PHProbe.plist
-rwxr-xr-x root/wheel   206768 2026-11-02 18:03 var/jb/Library/MobileSubstrate/DynamicLibraries/PhigrosAuto.dylib
-rw-r--r-- root/wheel       95 2026-11-02 18:03 var/jb/Library/MobileSubstrate/DynamicLibraries/PhigrosAuto.plist
drwxr-xr-x root/wheel        0 2026-11-02 18:02 var/jb/usr
drwxr-xr-x root/wheel        0 2026-11-02 18:02 var/jb/usr/bin
-rwxr-xr-x root/wheel     4399 2026-11-02 18:02 var/jb/usr/bin/phinject
-rwxr-xr-x root/wheel     9484 2026-11-02 18:02 var/jb/usr/bin/phprobe
```

## verify
```
Architecture: iphoneos-arm64
OK   Architecture=iphoneos-arm64
WARN 包内含 /var/jb/ 前缀
OK   含 PhigrosAuto.dylib
OK   含 PhigrosAuto.plist
extract rc=0
-rwxr-xr-x  1 runner  wheel  4399 Nov  2 18:02 /tmp/debx/var/jb/usr/bin/phinject
-rwxr-xr-x  1 runner  wheel  9484 Nov  2 18:02 /tmp/debx/var/jb/usr/bin/phprobe
-rwxr-xr-x  1 runner  wheel  206768 Nov  2 18:03 /tmp/debx/var/jb/Library/MobileSubstrate/DynamicLibraries/PhigrosAuto.dylib
-rw-r--r--  1 runner  wheel  95 Nov  2 18:03 /tmp/debx/var/jb/Library/MobileSubstrate/DynamicLibraries/PhigrosAuto.plist
-rw-r--r--  1 runner  wheel  93 Nov  2 18:03 /tmp/debx/var/jb/Library/MobileSubstrate/DynamicLibraries/PHProbe.plist
-rwxr-xr-x  1 runner  wheel  132880 Nov  2 18:03 /tmp/debx/var/jb/Library/MobileSubstrate/DynamicLibraries/PHProbe.dylib
dylib archs: arm64 arm64e
OK   dylib 含 arm64e 切片
OK   dylib 含 LC_CODE_SIGNATURE
OK   arm64 切片已签名
OK   arm64e 切片已签名
OK   control 无重复字段
--- verify result: FAIL=1 ---
```
