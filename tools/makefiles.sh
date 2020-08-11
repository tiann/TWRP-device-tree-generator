#!/bin/bash

make_Android.mk() {
	logstep "Generating Android.mk..."
	echo "LOCAL_PATH := \$(call my-dir)

ifeq (\$(TARGET_DEVICE),$DEVICE_CODENAME)
include \$(call all-subdir-makefiles,\$(LOCAL_PATH))
endif" >> Android.mk
	logdone
}

make_AndroidProducts.mk() {
	logstep "Generating AndroidProducts.mk..."
	echo "PRODUCT_MAKEFILES := \\
	\$(LOCAL_DIR)/omni_$DEVICE_CODENAME.mk" >> AndroidProducts.mk
	logdone
}

make_BoardConfig.mk() {
	logstep "Generating BoardConfig.mk..."
	echo "DEVICE_PATH := device/$DEVICE_TREE_PATH

# For building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true
" >> BoardConfig.mk

	if [ $DEVICE_ARCH = arm64 ]; then
		echo "# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_BOARD_SUFFIX := _64
TARGET_USES_64_BIT_BINDER := true
" >> BoardConfig.mk
	elif [ $DEVICE_ARCH = arm ]; then
		echo "# Architecture
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := generic
" >> BoardConfig.mk
	elif [ $DEVICE_ARCH = x86 ]; then
		echo "# Architecture
TARGET_ARCH := x86
TARGET_ARCH_VARIANT := generic
TARGET_CPU_ABI := x86
TARGET_CPU_ABI2 := armeabi-v7a
TARGET_CPU_ABI_LIST := x86,armeabi-v7a,armeabi
TARGET_CPU_ABI_LIST_32_BIT := x86,armeabi-v7a,armeabi
TARGET_CPU_VARIANT := generic
" >> BoardConfig.mk
	fi

	if [ "$BOOTLOADERNAME" != "" ]; then
		echo "# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := $KERNEL_BOOTLOADER_NAME
" >> BoardConfig.mk
	fi

	echo "# Kernel
BOARD_KERNEL_CMDLINE := $KERNEL_CMDLINE" >> BoardConfig.mk
	if [ "$DEVICE_IS_AB" = 1 ]; then
		echo "BOARD_KERNEL_CMDLINE += skip_override androidboot.fastboot=1" >> BoardConfig.mk
	fi
	echo "BOARD_KERNEL_BASE := $KERNEL_BASEADDRESS
BOARD_KERNEL_PAGESIZE := $KERNEL_PAGESIZE
BOARD_RAMDISK_OFFSET := $RAMDISK_OFFSET
BOARD_KERNEL_TAGS_OFFSET := $KERNEL_TAGS_OFFSET
BOARD_FLASH_BLOCK_SIZE := $((KERNEL_PAGESIZE * 64)) # (BOARD_KERNEL_PAGESIZE * 64)
TARGET_KERNEL_ARCH := $DEVICE_ARCH
TARGET_KERNEL_HEADER_ARCH := $DEVICE_ARCH
TARGET_KERNEL_SOURCE := kernel/$DEVICE_MANUFACTURER/$DEVICE_CODENAME
TARGET_KERNEL_CONFIG := ${DEVICE_CODENAME}_defconfig" >> BoardConfig.mk
	if [ "$KERNEL_HEADER_VERSION" != "0" ]; then
		echo "BOARD_BOOTIMG_HEADER_VERSION := $KERNEL_HEADER_VERSION" >> BoardConfig.mk
	fi
	if [ "$DEVICE_ARCH" = arm64 ]; then
		echo "BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb" >> BoardConfig.mk
	elif [ "$DEVICE_ARCH" = arm ]; then
		echo "BOARD_KERNEL_IMAGE_NAME := zImage-dtb" >> BoardConfig.mk
	elif [ "$DEVICE_ARCH" = x86 ]; then
		echo "BOARD_KERNEL_IMAGE_NAME := bzImage" >> BoardConfig.mk
	elif [ "$DEVICE_ARCH" = x86_64 ]; then
		echo "BOARD_KERNEL_IMAGE_NAME := bzImage" >> BoardConfig.mk
	fi
	if [ -f prebuilt/dt.img ]; then
		echo 'TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/zImage
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dt.img' >> BoardConfig.mk
	elif [ -f prebuilt/dtb.img ]; then
		echo 'TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/zImage
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb.img' >> BoardConfig.mk
	else
		echo 'TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/zImage-dtb' >> BoardConfig.mk
	fi
	if [ -f prebuilt/dtbo.img ]; then
		echo 'BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
BOARD_INCLUDE_RECOVERY_DTBO := true' >> BoardConfig.mk
	fi
	echo 'BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)' >> BoardConfig.mk
	if [ "$KERNEL_HEADER_VERSION" != "0" ]; then
		echo 'BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOTIMG_HEADER_VERSION)' >> BoardConfig.mk
	fi
	if [ -f prebuilt/dt.img ] || [ -f prebuilt/dtb.img ]; then
		echo 'BOARD_MKBOOTIMG_ARGS += --dt $(TARGET_PREBUILT_DTB)' >> BoardConfig.mk
	fi
	echo "" >> BoardConfig.mk

	case $RAMDISK_COMPRESSION_TYPE in
		lzma)
			echo "# LZMA
LZMA_RAMDISK_TARGETS := recovery
" >> BoardConfig.mk
			;;
	esac

	if [ $DEVICE_IS_SAR = 1 ]; then
		echo "# System as root
BOARD_BUILD_SYSTEM_ROOT_IMAGE := true
BOARD_SUPPRESS_SECURE_ERASE := true
" >> BoardConfig.mk
	fi

	echo "# Platform
# Fix this
#TARGET_BOARD_PLATFORM := 
#TARGET_BOARD_PLATFORM_GPU := 

# Assert
TARGET_OTA_ASSERT_DEVICE := $DEVICE_CODENAME

# Partitions
#BOARD_RECOVERYIMAGE_PARTITION_SIZE := $IMAGE_FILESIZE # This is the maximum known partition size, but it can be higher, so we just omit it

# File systems
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SYSTEMIMAGE_PARTITION_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4

# Workaround for error copying vendor files to recovery ramdisk
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_VENDOR := vendor

# Hack: prevent anti rollback
PLATFORM_SECURITY_PATCH := 2099-12-31
PLATFORM_VERSION := 16.1.0
" >> BoardConfig.mk

	if [ "$DEVICE_IS_AB" = 1 ]; then
		echo "# A/B" >> BoardConfig.mk
	echo "AB_OTA_UPDATER := true
TW_INCLUDE_REPACKTOOLS := true" >> BoardConfig.mk
	fi

	echo '# TWRP Configuration
TW_THEME := portrait_hdpi
TW_EXTRA_LANGUAGES := true
TW_SCREEN_BLANK_ON_BOOT := true
TW_INPUT_BLACKLIST := "hbtp_vm"
TW_USE_TOOLBOX := true' >> BoardConfig.mk
	logdone
}

make_omni_device.mk() {
	logstep "Generating omni_$DEVICE_CODENAME.mk..."
	echo '# Specify phone tech before including full_phone
$(call inherit-product, vendor/omni/config/gsm.mk)

# Inherit some common Omni stuff.
$(call inherit-product, vendor/omni/config/common.mk)
$(call inherit-product, build/target/product/embedded.mk)

# Inherit Telephony packages
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit language packages
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)
' >> "omni_$DEVICE_CODENAME.mk"

	# Inherit 64bit things if device is 64bit
	if [ $DEVICE_IS_64BIT = true ]; then
		echo '# Inherit 64bit support
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
' >> "omni_$DEVICE_CODENAME.mk"
	fi

# Add A/B flags
	if [ "$DEVICE_IS_AB" = 1 ]; then
		printf '# A/B
AB_OTA_PARTITIONS += \
    boot \
    system' >> "omni_$DEVICE_CODENAME.mk"
		if [ "$DEVICE_HAS_VENDOR_PARTITION" = true ]; then
			echo ' \
    vendor' >> "omni_$DEVICE_CODENAME.mk"
		else
			echo "" >> "omni_$DEVICE_CODENAME.mk"
		fi
	
		echo '
AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

# Boot control HAL
PRODUCT_PACKAGES += \
    android.hardware.boot@1.0-impl \
    android.hardware.boot@1.0-service

PRODUCT_PACKAGES += \
    bootctrl.$(TARGET_BOARD_PLATFORM)
    
PRODUCT_STATIC_BOOT_CONTROL_HAL := \
    bootctrl.$(TARGET_BOARD_PLATFORM) \
    libgptutils \
    libz \
    libcutils
    
PRODUCT_PACKAGES += \
    otapreopt_script \
    cppreopts.sh \
    update_engine \
    update_verifier \
    update_engine_sideload
' >> "omni_$DEVICE_CODENAME.mk"
	fi

	echo "# Device identifier. This must come after all inclusions
PRODUCT_DEVICE := $DEVICE_CODENAME
PRODUCT_NAME := omni_$DEVICE_CODENAME
PRODUCT_BRAND := $DEVICE_MANUFACTURER
PRODUCT_MODEL := $DEVICE_FULL_NAME
PRODUCT_MANUFACTURER := $DEVICE_MANUFACTURER
PRODUCT_RELEASE_NAME := $DEVICE_FULL_NAME" >> "omni_$DEVICE_CODENAME.mk"
	logdone
}

make_vendorsetup.sh() {
	logstep "Generating vendorsetup.sh..."
	echo "add_lunch_combo omni_$DEVICE_CODENAME-userdebug
add_lunch_combo omni_$DEVICE_CODENAME-eng" >> vendorsetup.sh
	logdone
}