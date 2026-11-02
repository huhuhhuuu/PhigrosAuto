TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES = Phigros

include $(THEOS)/makefiles/common.mk

# ------------------------------------------------------------
# 两个独立的 tweak，各自带自己的 filter plist：
#   PhigrosAuto.plist -> com.PigeonGames.Phigros
#   PHProbe.plist     -> com.apple.springboard
#
# PHProbe 是排查用的对照探针，只写一行心跳、不做别的事。
# 二元实验：桌面 marker 有、游戏 marker 没有 => 注入链正常、
# 问题在 Phigros 侧 filter 匹配；两个都没有 => 注入链本身坏了。
# ------------------------------------------------------------
TWEAK_NAME = PhigrosAuto PHProbe

# 纯 Objective-C，没有 %hook 之类的 Logos 语法，所以用 .m 而非 .xm，
# 不需要 substrate 头文件和库，CI 上更不容易出问题。
PhigrosAuto_FILES = Tweak.m IL2CPP.m IOHIDTouch.m NoteModel.m Autoplay.m PHLog.m
PhigrosAuto_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)
PhigrosAuto_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore

PHProbe_FILES = PHProbe.m
PHProbe_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

# 诊断脚本通过 layout/ 目录随包安装到 /var/jb/usr/bin/phprobe。
# 之前让用户手动 curl 下载脚本反复失败，直接打进 deb 最省事。
