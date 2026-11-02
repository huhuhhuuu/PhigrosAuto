# build log 2026-11-02T15:11:48Z
```
[0;36m==> [1;36mNotice:[m Build may be slow as Theos isn’t using all available CPU cores on this computer. Consider upgrading GNU Make: https://theos.dev/docs/parallel-building
[1;31m> [1;3;39mMaking all for tweak PhigrosAuto…[m
[0;32m==> [1;39mCompiling Tweak.m (arm64)…[m
[0;32m==> [1;39mCompiling IL2CPP.m (arm64)…[m
[0;32m==> [1;39mCompiling IOHIDTouch.m (arm64)…[m
[0;32m==> [1;39mCompiling NoteModel.m (arm64)…[m
[0;32m==> [1;39mCompiling Autoplay.m (arm64)…[m
[0;33m==> [1;39mLinking tweak PhigrosAuto (arm64)…[m
ld: warning: -multiply_defined is obsolete
[0;34m==> [1;39mGenerating debug symbols for PhigrosAuto…[m
[0;34m==> [1;39mStripping PhigrosAuto (arm64)…[m
[0;32m==> [1;39mCompiling Tweak.m (arm64e)…[m
[0;32m==> [1;39mCompiling IL2CPP.m (arm64e)…[m
[0;32m==> [1;39mCompiling IOHIDTouch.m (arm64e)…[m
[0;32m==> [1;39mCompiling NoteModel.m (arm64e)…[m
[0;32m==> [1;39mCompiling Autoplay.m (arm64e)…[m
[0;33m==> [1;39mLinking tweak PhigrosAuto (arm64e)…[m
ld: warning: -multiply_defined is obsolete
[0;34m==> [1;39mGenerating debug symbols for PhigrosAuto…[m
[0;34m==> [1;39mStripping PhigrosAuto (arm64e)…[m
[0;34m==> [1;39mMerging tweak PhigrosAuto…[m
[0;34m==> [1;39mSigning PhigrosAuto…[m
[1;31m> [1;3;39mMaking stage for tweak PhigrosAuto…[m
dyld[2770]: terminating because inserted dylib '/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot.dylib' could not be loaded: tried: '/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot.dylib' (mach-o file, but is an incompatible architecture (have 'arm64', need 'arm64e')), '/System/Volumes/Preboot/Cryptexes/OS/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot.dylib' (no such file), '/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot.dylib' (mach-o file, but is an incompatible architecture (have 'arm64', need 'arm64e')), '/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot-0.dylib' (mach-o file, but is an incompatible architecture (have 'arm64', need 'arm64e')), '/System/Volumes/Preboot/Cryptexes/OS/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot-0.dylib' (no such file), '/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot-0.dylib' (mach-o file, but is an incompatible architecture (have 'arm64', need 'arm64e'))
dyld[2770]: tried: '/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot.dylib' (mach-o file, but is an incompatible architecture (have 'arm64', need 'arm64e')), '/System/Volumes/Preboot/Cryptexes/OS/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot.dylib' (no such file), '/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot.dylib' (mach-o file, but is an incompatible architecture (have 'arm64', need 'arm64e')), '/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot-0.dylib' (mach-o file, but is an incompatible architecture (have 'arm64', need 'arm64e')), '/System/Volumes/Preboot/Cryptexes/OS/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot-0.dylib' (no such file), '/opt/homebrew/Cellar/fakeroot/2.1.4/lib/libfakeroot-0.dylib' (mach-o file, but is an incompatible architecture (have 'arm64', need 'arm64e'))
/opt/homebrew/bin/fakeroot: line 178:  2770 Abort trap: 6           FAKEROOTKEY=$FAKEROOTKEY DYLD_INSERT_LIBRARIES="$FAKEROOT_LIB" "$@"
/opt/homebrew/bin/fakeroot: line 180:  2771 Abort trap: 6           exit $RESULT
make: *** [internal-package] Error 134
```
