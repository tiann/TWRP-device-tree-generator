#!/bin/bash
#
# Copyright (C) 2020 The Android Open Source Project
# Copyright (C) 2020 The TWRP Open Source Project
# Copyright (C) 2020 SebaUbuntu's TWRP device tree generator 
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

VERSION="1.3"

SCRIPT_PWD=$(pwd)

if [ "$1" = "--cli" ]; then
	USE_GUI=false
fi

# Source additional tools
source ./tools/adb.sh
source ./tools/files.sh
source ./tools/fstab.sh
source ./tools/git.sh
source ./tools/graphics.sh
source ./tools/makefiles.sh
source ./tools/user_interaction.sh

set_colors
clean_screen
logo

LAST_COMMIT=$(git log -1 --format="%h")
if [ ${#LAST_COMMIT} != 7 ]; then
	error "Failed retreiving last git commit
Please use git clone, and don't download repo zip file
If you don't have it, also install git"
	exit
fi

# Clone AIK on startup
[ -d extract ] && rm -rf extract
git clone https://github.com/SebaUbuntu/AIK-Linux-mirror extract

# Ask user for device info because we don't use build.prop
logo
DEVICE_CODENAME=$(get_info "Insert the device codename (eg. whyred)")
if [ -z "$DEVICE_CODENAME" ]; then
	error "Device codename can't be empty"
	exit
fi
clean_screen

logo
DEVICE_MANUFACTURER=$(get_info "Insert the device manufacturer (eg. xiaomi)")
if [ -z "$DEVICE_MANUFACTURER" ]; then
	error "Device manufacturer can't be empty"
	exit
fi
# Manufacturer name must be lowercase
DEVICE_MANUFACTURER=$(echo "$DEVICE_MANUFACTURER" | tr '[:upper:]' '[:lower:]')
clean_screen

logo
DEVICE_YEAR_RELEASE=$(get_info "Insert the device release year (eg. 2018)")
if [ -z "$DEVICE_YEAR_RELEASE" ]; then
	error "Device year release can't be empty"
	exit
fi
clean_screen

logo
DEVICE_FULL_NAME=$(get_info "Insert the device commercial name (eg. Xiaomi Redmi Note 5)")
if [ -z "$DEVICE_FULL_NAME" ]; then
	error "Device commercial name can't be empty"
	exit
fi
clean_screen

logo
DEVICE_IS_AB=$(get_boolean "Is the device A/B?")
if [ -z "$DEVICE_IS_AB" ]; then
	info "Nothing inserted, assuming A-only device"
	sleep 1
elif [ "$DEVICE_IS_AB" != 1 ] && [ "$DEVICE_IS_AB" != 0 ]; then
	error "Wrong input"
	exit
fi
clean_screen

logo
DEVICE_STOCK_RECOVERY_PATH=$(get_file_path "recovery image (or a boot image if the device is A/B)" "*.img")
if [ ! -f "$DEVICE_STOCK_RECOVERY_PATH" ]; then
	error "File not found"
	exit
fi
clean_screen

logo
ADB_CHOICE=$(get_boolean "Do you want to add additional flags via ADB? (Optional)
This can help the script by taking precise data
But you need to have the device on hands and adb command needs to be present")
if [ -z "$ADB_CHOICE" ]; then
	info "Nothing inserted, assuming ADB won't be used"
	sleep 1
elif [ "$ADB_CHOICE" != 1 ] && [ "$ADB_CHOICE" != 0 ]; then
	error "Wrong input"
	exit
fi
clean_screen

# Start generation
logo

[ -f "$SCRIPT_PWD/$DEVICE_CODENAME.log" ] && rm -f "$SCRIPT_PWD/$DEVICE_CODENAME.log"
loginfo "
------------------------------------------------------------------------
SebaUbuntu's TWRP device tree generator
Version=$VERSION
Device name=$DEVICE_FULL_NAME
Device codename=$DEVICE_CODENAME
Date and time=$(date)
OS=$(uname)
------------------------------------------------------------------------

Starting device tree generation
"

if [ "$ADB_CHOICE" = "1" ]; then
	adb_check_device
	if [ $? = 0 ]; then
		printf "${blue}Device connected, taking values, do not disconnect the device..."
		DEVICE_SOC_MANUFACTURER=$(adb_get_prop ro.hardware)
		echo " done${reset}"
	else
		error "Device not connected or ADB is not installed"
		logerror "Device not connected or ADB is not installed"
	fi
else
	loginfo "ADB will be skipped"
fi

if [ "$DEVICE_SOC_MANUFACTURER" != "" ]; then
	loginfo "Device SoC manufacturer is $DEVICE_SOC_MANUFACTURER"
fi

# Path declarations
SPLITIMG_DIR=extract/split_img
RAMDISK_DIR=extract/ramdisk
DEVICE_TREE_PATH="$DEVICE_MANUFACTURER/$DEVICE_CODENAME"

# Start cleanly
rm -rf "$DEVICE_TREE_PATH"
mkdir -p "$DEVICE_TREE_PATH/prebuilt"
mkdir -p "$DEVICE_TREE_PATH/recovery/root"

# Obtain stock recovery.img size
cp "$DEVICE_STOCK_RECOVERY_PATH" "extract/$DEVICE_CODENAME.img"
logstep "Obtaining stock recovery image info..."
IMAGE_FILESIZE=$(du -b "extract/$DEVICE_CODENAME.img" | cut -f1)
cd extract

# Obtain recovery.img format info
logstep "$(./unpackimg.sh --nosudo "$DEVICE_CODENAME.img")"
cd ..
KERNEL_BOOTLOADER_NAME=$(cat "$SPLITIMG_DIR/$DEVICE_CODENAME.img-board")
KERNEL_CMDLINE=$(cat "$SPLITIMG_DIR/$DEVICE_CODENAME.img-cmdline")
KERNEL_PAGESIZE=$(cat "$SPLITIMG_DIR/$DEVICE_CODENAME.img-pagesize")
KERNEL_BASEADDRESS=$(cat "$SPLITIMG_DIR/$DEVICE_CODENAME.img-base")
RAMDISK_OFFSET=$(cat "$SPLITIMG_DIR/$DEVICE_CODENAME.img-ramdisk_offset")
KERNEL_TAGS_OFFSET=$(cat "$SPLITIMG_DIR/$DEVICE_CODENAME.img-tags_offset")
RAMDISK_COMPRESSION_TYPE=$(cat "$SPLITIMG_DIR/$DEVICE_CODENAME.img-ramdiskcomp")
KERNEL_HEADER_VERSION=$(cat "$SPLITIMG_DIR/$DEVICE_CODENAME.img-header_version")

logdone

# See what arch is by analizing init executable
BINARY=$(file "$RAMDISK_DIR/init")

# // Android 10 change: now init binary is a symlink to /system/etc/init, check for other binary files
if [ "$(echo "$BINARY" | grep -o "symbolic")" = "symbolic" ]; then
	loginfo "Init binary not found, using a random binary"
	for i in $(ls "$RAMDISK_DIR/sbin"); do
		BINARY=$(file "$RAMDISK_DIR/sbin/$i")
		if [ "$(echo "$BINARY" | grep -o "symbolic")" != "symbolic" ]; then
			BINARY_FOUND=true
			break
		fi
		[ "$BINARY_FOUND" ] && break
	done
	if [ "$BINARY_FOUND" != true ]; then
		for i in $(ls "$RAMDISK_DIR/system/lib64"); do
			BINARY=$(file "$RAMDISK_DIR/system/lib64/$i")
			if [ "$(echo "$BINARY" | grep -o "symbolic")" != "symbolic" ]; then
				BINARY_FOUND=true
				break
			fi
			[ "$BINARY_FOUND" ] && break
		done
	fi
	if [ "$BINARY_FOUND" != true ]; then
		for i in $(ls "$RAMDISK_DIR/vendor/lib64"); do
			BINARY=$(file "$RAMDISK_DIR/vendor/lib64/$i")
			if [ "$(echo "$BINARY" | grep -o "symbolic")" != "symbolic" ]; then
				BINARY_FOUND=true
				break
			fi
			[ "$BINARY_FOUND" ] && break
		done
	fi
	if [ "$BINARY_FOUND" != true ]; then
		for i in $(ls "$RAMDISK_DIR/system/lib"); do
			BINARY=$(file "$RAMDISK_DIR/system/lib/$i")
			if [ "$(echo "$BINARY" | grep -o "symbolic")" != "symbolic" ]; then
				BINARY_FOUND=true
				break
			fi
			[ "$BINARY_FOUND" ] && break
		done
	fi
	if [ "$BINARY_FOUND" != true ]; then
		for i in $(ls "$RAMDISK_DIR/vendor/lib"); do
			BINARY=$(file "$RAMDISK_DIR/vendor/lib/$i")
			if [ "$(echo "$BINARY" | grep -o "symbolic")" != "symbolic" ]; then
				BINARY_FOUND=true
				break
			fi
			[ "$BINARY_FOUND" ] && break
		done
	fi
	if [ "$BINARY_FOUND" != true ]; then
		error "Script can't find a binary file, aborting"
		logerror "Script can't find a binary file, aborting"
		exit
	fi
fi

if echo "$BINARY" | grep -q ARM; then
	if echo "$BINARY" | grep -q aarch64; then
		DEVICE_ARCH=arm64
		DEVICE_IS_64BIT=true
	else
		DEVICE_ARCH=arm
		DEVICE_IS_64BIT=false
	fi
elif echo "$BINARY" | grep -q x86; then	
	if echo "$BINARY" | grep -q x86-64; then
		DEVICE_ARCH=x86_64
		DEVICE_IS_64BIT=true
	else
		DEVICE_ARCH=x86
		DEVICE_IS_64BIT=false
	fi
else
	# Nothing matches, were you trying to make TWRP for Symbian OS devices, Playstation 2 or PowerPC-based Macintosh?
	error "Arch not supported"
	logerror "Arch not supported"
	exit
fi

if [ $DEVICE_ARCH = x86_64 ]; then
	# idk how you can have a x86_64 Android based device, unless it's Android-x86 project
	error "x86_64 arch is not supported for now!"
	logerror "x86_64 arch is not supported for now!"
	exit
fi

loginfo "Device is $DEVICE_ARCH"

# Check if device tree blobs are not appended to kernel and copy kernel
if [ -f "$SPLITIMG_DIR/$DEVICE_CODENAME.img-dt" ]; then
	loginfo "DTB are not appended to kernel"
	logstep "Copying kernel..."
	cp "$SPLITIMG_DIR/$DEVICE_CODENAME.img-zImage" "$DEVICE_TREE_PATH/prebuilt/zImage"
	logdone
	logstep "Copying DTB..."
	cp "$SPLITIMG_DIR/$DEVICE_CODENAME.img-dt" "$DEVICE_TREE_PATH/prebuilt/dt.img"
	logdone
elif [ -f "$SPLITIMG_DIR/$DEVICE_CODENAME.img-dtb" ]; then
	loginfo "DTB are not appended to kernel"
	logstep "Copying kernel..."
	cp "$SPLITIMG_DIR/$DEVICE_CODENAME.img-zImage" "$DEVICE_TREE_PATH/prebuilt/zImage"
	logdone
	logstep "Copying DTB..."
	cp "$SPLITIMG_DIR/$DEVICE_CODENAME.img-dtb" "$DEVICE_TREE_PATH/prebuilt/dtb.img"
	logdone
else
	loginfo "DTB are appended to kernel"
	logstep "Copying kernel..."
	cp "$SPLITIMG_DIR/$DEVICE_CODENAME.img-zImage" "$DEVICE_TREE_PATH/prebuilt/zImage-dtb"
	logdone
fi

# Check if dtbo image is present
if [ -f "$SPLITIMG_DIR/$DEVICE_CODENAME.img-recovery_dtbo" ]; then
	loginfo "DTBO image exists"
	logstep "Copying DTBO..."
	cp "$SPLITIMG_DIR/$DEVICE_CODENAME.img-recovery_dtbo" "$DEVICE_TREE_PATH/prebuilt/dtbo.img"
	logdone
fi

# Check if a fstab is present
if [ -f "$RAMDISK_DIR/etc/twrp.fstab" ]; then
	logstep "A TWRP fstab has been found, copying it..."
	cp "$RAMDISK_DIR/etc/twrp.fstab" "$DEVICE_TREE_PATH/recovery.fstab"
	# Do a quick check if vendor partition is present
	if [ $(grep vendor "$DEVICE_TREE_PATH/recovery.fstab" > /dev/null; echo $?) = 0 ]; then
		DEVICE_HAS_VENDOR_PARTITION=true
	fi
	logdone
elif [ -f "$RAMDISK_DIR/etc/recovery.fstab" ]; then
	logstep "Extracting fstab..."
	cp "$RAMDISK_DIR/etc/recovery.fstab" "$DEVICE_TREE_PATH/fstab.temp"
	logdone
elif [ -f "$RAMDISK_DIR/system/etc/recovery.fstab" ]; then
	logstep "Extracting fstab..."
	cp "$RAMDISK_DIR/system/etc/recovery.fstab" "$DEVICE_TREE_PATH/fstab.temp"
	logdone
else
	error "The script haven't found any fstab, so you will need to make your own fstab based on what partitions you have"
	logerror "The script haven't found any fstab"
fi

# Extract init.rc files
logstep "Extracting init.rc files..."
for i in $(ls $RAMDISK_DIR | grep ".rc"); do
	if [ "$i" != init.rc ]; then
		cp "$RAMDISK_DIR/$i" "$DEVICE_TREE_PATH/recovery/root"
	fi
done
logdone

# Cleanup
rm "extract/$DEVICE_CODENAME.img"
rm -rf $SPLITIMG_DIR
rm -rf $RAMDISK_DIR

cd "$DEVICE_TREE_PATH"

# License - please keep it as is, thanks
logstep "Adding license headers..."
CURRENT_YEAR="$(date +%Y)"
for file in Android.mk AndroidProducts.mk BoardConfig.mk omni_$DEVICE_CODENAME.mk vendorsetup.sh; do
	license_headers "$file"
done
logdone

# Generate custom fstab if it's not ready
if [ -f fstab.temp ]; then
	logstep "Generating fstab..."
	generate_fstab fstab.temp
	rm fstab.temp
	logdone
fi

# Check for system-as-root setup
if [ "$(cat recovery.fstab | grep -w "system_root")" != "" ]; then
	loginfo "Device is system-as-root"
	DEVICE_IS_SAR=1
else
	loginfo "Device is not system-as-root"
	DEVICE_IS_SAR=0
fi

case $RAMDISK_COMPRESSION in
	lzma)
		loginfo "Kernel support lzma compression, using it"
		;;
esac

# Create the device tree structure
make_Android.mk
make_AndroidProducts.mk
make_BoardConfig.mk
make_omni_device.mk
make_vendorsetup.sh

# Add system-as-root declaration
if [ $DEVICE_IS_SAR = 1 ]; then
	echo "on fs
	export ANDROID_ROOT /system_root" >> recovery/root/init.recovery.sar.rc
fi

# Automatically create a ready-to-push repo
create_git_repo

echo "Device tree successfully made, you can find it in $DEVICE_TREE_PATH

Note: This device tree should already work, but there can be something that prevent booting the recovery, for example a kernel with OEM modifications that doesn't let boot a custom recovery, or that disable touch on recovery
If this is the case, then see if OEM provide kernel sources and build the kernel by yourself
Here below there is the generation log

$(cat $SCRIPT_PWD/$DEVICE_CODENAME.log)" > exit_message.txt
success "exit_message.txt"
rm "exit_message.txt"