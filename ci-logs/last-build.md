# build log 2026-11-02T16:42:49Z

## make package
```
[0;36m==> [1;36mNotice:[m Build may be slow as Theos isn’t using all available CPU cores on this computer. Consider upgrading GNU Make: https://theos.dev/docs/parallel-building
[1;31m> [1;3;39mMaking all for tweak PhigrosAuto…[m
[0;32m==> [1;39mCompiling Tweak.m (arm64)…[m
[1mTweak.m:187:33: [0m[0;1;31merror: [0m[1mformat specifies type 'int' but the argument has type 'CGFloat' (aka 'double') [-Werror,-Wformat][0m
              host.windowLevel, host.bounds.size.width, host.bounds.size.height);
[0;1;32m                                ^~~~~~~~~~~~~~~~~~~~~~
[0m[1mTweak.m:143:29: [0m[0;1;31merror: [0m[1m'windows' is deprecated: first deprecated in iOS 15.0 - Use UIWindowScene.windows on a relevant window scene instead [-Werror,-Wdeprecated-declarations][0m
    for (UIWindow *w in app.windows) {
[0;1;32m                            ^
[0m[1m/Applications/Xcode_15.4.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS17.5.sdk/System/Library/Frameworks/UIKit.framework/Headers/UIApplication.h:109:62: [0m[0;1;30mnote: [0m'windows' has been explicitly marked deprecated here[0m
@property(nonatomic,readonly) NSArray<__kindof UIWindow *>  *windows API_DEPRECATED("Use UIWindowScene.windows on a relevant window scene instead", ios(2.0, 15.0), visionos(1.0, 1.0));
[0;1;32m                                                             ^
[0m[1mTweak.m:150:16: [0m[0;1;31merror: [0m[1m'windows' is deprecated: first deprecated in iOS 15.0 - Use UIWindowScene.windows on a relevant window scene instead [-Werror,-Wdeprecated-declarations][0m
    return app.windows.firstObject;
[0;1;32m               ^
[0m[1m/Applications/Xcode_15.4.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS17.5.sdk/System/Library/Frameworks/UIKit.framework/Headers/UIApplication.h:109:62: [0m[0;1;30mnote: [0m'windows' has been explicitly marked deprecated here[0m
@property(nonatomic,readonly) NSArray<__kindof UIWindow *>  *windows API_DEPRECATED("Use UIWindowScene.windows on a relevant window scene instead", ios(2.0, 15.0), visionos(1.0, 1.0));
[0;1;32m                                                             ^
[0m3 errors generated.
make[3]: *** [/Users/runner/work/PhigrosAuto/PhigrosAuto/.theos/obj/arm64/Tweak.m.4173dfc0.o] Error 1
make[2]: *** [/Users/runner/work/PhigrosAuto/PhigrosAuto/.theos/obj/arm64/PhigrosAuto.dylib] Error 2
make[1]: *** [internal-library-all_] Error 2
make: *** [PhigrosAuto.all.tweak.variables] Error 2
```

## package
```
=== ls packages ===
ls: packages/: No such file or directory
DEB=
```

## verify
```
no verify.log
```
