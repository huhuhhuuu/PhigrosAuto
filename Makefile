TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES = Phigros

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PhigrosAuto
# 纯 Objective-C，没有 %hook 之类的 Logos 语法，因此用 .m 而非 .xm。
# 这样也不需要 substrate 的头文件和库，CI 上更不容易出问题。
PhigrosAuto_FILES = Tweak.m IL2CPP.m IOHIDTouch.m NoteModel.m Autoplay.m
PhigrosAuto_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)
PhigrosAuto_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
