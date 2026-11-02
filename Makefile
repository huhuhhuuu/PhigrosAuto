TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES = Phigros

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PhigrosAuto
PhigrosAuto_FILES = Tweak.xm IL2CPP.m IOHIDTouch.m NoteModel.m Autoplay.m
PhigrosAuto_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)
PhigrosAuto_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore
PhigrosAuto_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
