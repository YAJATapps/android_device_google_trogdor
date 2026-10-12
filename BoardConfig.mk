#
# Copyright (C) 2026 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

DEVICE_PATH := device/google/trogdor

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_VARIANT := cortex-a76
TARGET_CPU_ABI := arm64-v8a
TARGET_SUPPORTS_64_BIT_APPS := true

# Platform
TARGET_BOOTLOADER_BOARD_NAME := trogdor
TARGET_BOARD_PLATFORM := trogdor

# Kernel
TARGET_NO_KERNEL := false
TARGET_KERNEL_SOURCE := kernel/google/trogdor
TARGET_KERNEL_CONFIG := trogdor_defconfig
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
TARGET_DTB_LIST_WILDCARD := sc7180-trogdor*
BOARD_BOOT_HEADER_VERSION := 2
BOARD_KERNEL_PAGESIZE := 4096

BOARD_MKBOOTIMG_ARGS := --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --base 0x0 --kernel_offset 0x0 --ramdisk_offset 0x0
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)

BOARD_KERNEL_CMDLINE := earlycon
BOARD_KERNEL_CMDLINE += firmware_class.path=/vendor/firmware,/vendor/firmware/qcom
BOARD_KERNEL_CMDLINE += init=/init printk.devkmsg=on
BOARD_KERNEL_CMDLINE += deferred_probe_timeout=30
BOARD_KERNEL_CMDLINE += qcom_geni_serial.con_enabled=1
BOARD_KERNEL_CMDLINE += androidboot.boot_part_uuid=%U
BOARD_KERNEL_CMDLINE += androidboot.hardware=trogdor
BOARD_KERNEL_CMDLINE += androidboot.verifiedbootstate=orange
BOARD_KERNEL_CMDLINE += androidboot.slot_suffix=_a
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive

# File systems & Partitions
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_F2FS_BLOCKSIZE := 4096
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_PRODUCT := product
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_USES_METADATA_PARTITION := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/fstab.trogdor

# Dynamic Partitions
TARGET_USE_DYNAMIC_PARTITIONS := true
BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := true
BOARD_SUPER_PARTITION_METADATA_DEVICE := super
BOARD_SUPER_IMAGE_IN_UPDATE_PACKAGE := true
BOARD_SUPER_PARTITION_SIZE := 12437225472
BOARD_TROGDOR_DYNAMIC_PARTITIONS_SIZE := 12433031168 # Reserve 4M for DAP metadata
BOARD_SUPER_PARTITION_GROUPS := trogdor_dynamic_partitions
BOARD_TROGDOR_DYNAMIC_PARTITIONS_PARTITION_LIST := system vendor system_ext product

BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296 # 96M
BOARD_USERDATAIMAGE_PARTITION_SIZE := 21474836480 # 20G
BOARD_FLASH_BLOCK_SIZE := 4096

# DLKM partitions
include $(DEVICE_PATH)/shared/utils/dlkm_loader/BoardConfig.mk
BOARD_TROGDOR_DYNAMIC_PARTITIONS_PARTITION_LIST += system_dlkm vendor_dlkm
BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/shared/utils/dlkm_loader/sepolicy/

# Treble & VINTF
PRODUCT_FULL_TREBLE := true
BOARD_VNDK_VERSION := current
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml

# Graphics (drm_hwcomposer + [mesa | swangle] + minigbm_msm)
include $(DEVICE_PATH)/shared/graphics/drm_hwcomposer/BoardConfig.mk
BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/shared/graphics/minigbm_msm/sepolicy/

TARGET_BUILD_MESA ?= true
ifeq ($(TARGET_BUILD_MESA), true)
include $(DEVICE_PATH)/shared/graphics/mesa/BoardConfig.mk
else
BOARD_SEPOLICY_DIRS += \
    $(DEVICE_PATH)/shared/graphics/swangle/sepolicy/
endif

# Wi-Fi
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_WLAN_DEVICE := qcwcn

# Bluetooth
BOARD_HAVE_BLUETOOTH := true

# SELinux
BOARD_SEPOLICY_DIRS += \
    $(DEVICE_PATH)/sepolicy

# Dexpreopt
ifeq ($(HOST_OS),linux)
  ifeq ($(WITH_DEXPREOPT),)
    WITH_DEXPREOPT := true
    WITH_DEXPREOPT_PIC := true
  endif
endif

BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Inherit from vendor BoardConfig if available
-include vendor/google/trogdor/BoardConfigVendor.mk
