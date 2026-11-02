TWEAK_NAME = PhigrosAuto
# 纯 Objective-C，没有 %hook 之类的 Logos 语法，因此用 .m 而非 .xm。
# 这样也不需要 substrate 的头文件和库，CI 上更不容易出问题。
PhigrosAuto_FILES = Tweak.m IL2CPP.m IOHIDTouch.m NoteModel.m Autoplay.m PHLog.m
PhigrosAuto_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)
PhigrosAuto_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

# 诊断脚本通过 layout/ 目录随包安装到 /var/jb/usr/bin/phprobe。
# 之前让用户手动 curl 下载脚本反复失败（第 4 次了），
# 直接打进 deb 最省事，装完终端敲 phprobe 即可。
