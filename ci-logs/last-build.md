# build log 2026-11-02T15:08:46Z
```
[0;36m==> [1;36mNotice:[m Build may be slow as Theos isn’t using all available CPU cores on this computer. Consider upgrading GNU Make: https://theos.dev/docs/parallel-building
[1;31m> [1;3;39mMaking all for tweak PhigrosAuto…[m
[0;32m==> [1;39mCompiling Tweak.m (arm64)…[m
[1mTweak.m:158:51: [0m[0;1;31merror: [0m[1mcapturing 'poll' strongly in this block is likely to lead to a retain cycle [-Werror,-Warc-retain-cycles][0m
                       dispatch_get_main_queue(), poll);
[0;1;32m                                                  ^~~~
[0m[1mTweak.m:147:5: [0m[0;1;30mnote: [0mblock will be retained by the captured object[0m
    poll = ^{
[0;1;32m    ^~~~
[0m1 error generated.
make[3]: *** [/Users/runner/work/PhigrosAuto/PhigrosAuto/.theos/obj/arm64/Tweak.m.4173dfc0.o] Error 1
make[2]: *** [/Users/runner/work/PhigrosAuto/PhigrosAuto/.theos/obj/arm64/PhigrosAuto.dylib] Error 2
make[1]: *** [internal-library-all_] Error 2
make: *** [PhigrosAuto.all.tweak.variables] Error 2
```
