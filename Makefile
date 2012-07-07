TWEAK_NAME = ChromeCustomization
ChromeCustomization_FILES = Tweak.x CCTrackingPrivacyList.m
ChromeCustomization_FRAMEWORKS = Foundation UIKit QuartzCore

ADDITIONAL_CFLAGS = -std=c99
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 5.0

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk
