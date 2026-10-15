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

# Dalvik VM heap
$(call inherit-product, frameworks/native/build/tablet-10in-xhdpi-2048-dalvik-heap.mk)

# Enable updating of APEXes
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# Enable Scoped Storage
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Virtual A/B OTA
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)

# Device overlay
DEVICE_PACKAGE_OVERLAYS := $(DEVICE_PATH)/overlay

# Dynamic partitions
PRODUCT_BUILD_SUPER_PARTITION := true
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true

# A/B OTA Partitions
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    product \
    system \
    system_ext \
    vendor

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH) \
    hardware/qcom/wlan \
    hardware/qcom/wlan/legacy

# DLKM Loader
include $(DEVICE_PATH)/shared/utils/dlkm_loader/device.mk
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/shared/utils/dlkm_loader/dlkm_loader.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/dlkm_loader.rc \
    $(DEVICE_PATH)/scripts/expand_userdata.sh:$(TARGET_COPY_OUT_VENDOR)/bin/expand_userdata.sh \
    $(DEVICE_PATH)/scripts/install_to_emmc.sh:$(TARGET_COPY_OUT_VENDOR)/bin/install_to_emmc.sh \
    $(DEVICE_PATH)/scripts/setup_audio.sh:$(TARGET_COPY_OUT_VENDOR)/bin/setup_audio.sh

PRODUCT_PACKAGES += \
    blkpg_resize \
    InstallAndroid

# IDC
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/idc/Vendor_0603_Product_604a.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/Vendor_0603_Product_604a.idc

#    $(DEVICE_PATH)/idc/Google_Inc._Hammer.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/Google_Inc._Hammer.idc

# BootControl HAL
PRODUCT_PACKAGES += \
    com.android.hardware.boot \
    android.hardware.boot-service.default_recovery

# Power, Health, and Thermal AIDL HALs
PRODUCT_PACKAGES += \
    android.hardware.power-service.example \
    android.hardware.power.stats-service.example \
    com.android.hardware.thermal \
    android.hardware.health-service.example \
    suspend_blocker

# Lights HAL
PRODUCT_PACKAGES += \
    android.hardware.light-service.lineage

# Security HALs (KeyMint & Gatekeeper software implementations)
PRODUCT_PACKAGES += \
    com.android.hardware.keymint.rust_nonsecure \
    com.android.hardware.gatekeeper.nonsecure

# DRM HAL
PRODUCT_PACKAGES += \
    android.hardware.drm-service.clearkey

# Launcher
PRODUCT_PACKAGES += Launcher3QuickStep

# Fstab
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/fstab.trogdor:$(TARGET_COPY_OUT_RAMDISK)/first_stage_ramdisk/fstab.trogdor \
    $(DEVICE_PATH)/fstab.trogdor:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.trogdor

# Init scripts & configs
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init.trogdor.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.trogdor.rc \
    $(DEVICE_PATH)/init.trogdor.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.trogdor.usb.rc \
    $(DEVICE_PATH)/ueventd.trogdor.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.rc \
    frameworks/base/data/keyboards/Generic.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/trogdor.kl


# Wi-Fi
FORCE_USE_ANDROIDMK_FOR_WPA_CONF := true
PRODUCT_PACKAGES += \
    android.hardware.wifi-service \
    hostapd \
    libcld80211 \
    libwpa_client \
    wpa_supplicant \
    wpa_supplicant.conf \
    wificond

PRODUCT_PROPERTY_OVERRIDES += \
    wifi.interface=wlan0 \
    wifi.direct.interface=p2p-dev-wlan0 \
    wifi.supplicant_scan_interval=15

# Enable authenticated ADB over the device's Ethernet interfaces for debugging.
PRODUCT_VENDOR_PROPERTIES += \
    service.adb.tcp.port=5555

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.passpoint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.passpoint.xml \
    $(DEVICE_PATH)/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf \
    $(DEVICE_PATH)/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf

# Bluetooth
PRODUCT_PACKAGES += \
    android.hardware.bluetooth-service.default \
    bdaddr

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    $(DEVICE_PATH)/shared/utils/bdaddr/set_bdaddr.sh:$(TARGET_COPY_OUT_VENDOR)/bin/set_bdaddr.sh

# Audio HAL (AIDL) & CLI tools
PRODUCT_PACKAGES += \
    audio.bluetooth.default \
    audio.usb.default \
    audio.r_submix.default \
    tinyplay \
    tinycap \
    tinymix \
    tinypcminfo \
    com.android.hardware.audio

PRODUCT_VENDOR_PROPERTIES += \
    ro.hardware.audio.tinyalsa.period_count=2 \
    ro.hardware.audio.tinyalsa.period_size_multiplier=3

PRODUCT_VENDOR_PROPERTIES += media.c2.hal.selection=aidl

USE_XML_AUDIO_POLICY_CONF := 1
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/etc/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    $(DEVICE_PATH)/etc/audio_policy_configuration_homestar.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration_homestar.xml \
    hardware/interfaces/audio/aidl/default/audio_effects_config.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects_config.xml \
    frameworks/av/services/audiopolicy/config/bluetooth_audio_policy_configuration_7_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth_audio_policy_configuration_7_0.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml

# Chrome EC IIO sensor HAL
PRODUCT_PACKAGES += \
    android.hardware.sensors-service.multihal \
    android.hardware.sensors@2.1-trogdor-subhal

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/etc/sensors/hals.conf:$(TARGET_COPY_OUT_VENDOR)/etc/sensors/hals.conf \
    $(DEVICE_PATH)/etc/sensors/sensor_hal_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/sensors/sensor_hal_configuration.xml

# Media codecs & profiles
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/etc/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    frameworks/av/media/libeffects/data/audio_effects.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_audio.xml

# Seccomp policy
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/seccomp_policy/mediaswcodec.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediacodec.policy \
    $(DEVICE_PATH)/seccomp_policy/mediaswcodec.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediaswcodec.policy


# Qualcomm userspace services
PRODUCT_PACKAGES += \
    qrtr-ns \
    qrtr-cfg \
    qrtr-lookup \
    efs-loader \
    rmtfs \
    tqftpserv

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/shared/utils/init.utils.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.utils.rc

# Hardware scripts
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/shared/utils/set_hw.sh:$(TARGET_COPY_OUT_VENDOR)/bin/set_hw.sh \
    $(DEVICE_PATH)/shared/utils/set_udc.sh:$(TARGET_COPY_OUT_VENDOR)/bin/set_udc.sh \
    $(DEVICE_PATH)/shared/utils/ethaddr/ethaddr.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/ethaddr.rc \
    $(DEVICE_PATH)/shared/utils/ethaddr/set_ethaddr.sh:$(TARGET_COPY_OUT_VENDOR)/bin/set_ethaddr.sh

# Graphics (drm_hwcomposer + [mesa | swangle] + minigbm_msm)
$(call inherit-product, $(DEVICE_PATH)/shared/graphics/drm_hwcomposer/device.mk)
$(call inherit-product, $(DEVICE_PATH)/shared/graphics/minigbm_msm/device.mk)

TARGET_BUILD_MESA ?= true
ifeq ($(TARGET_BUILD_MESA), true)
$(call inherit-product, $(DEVICE_PATH)/shared/graphics/mesa/device.mk)
else
$(call inherit-product, $(DEVICE_PATH)/shared/graphics/swangle/device.mk)
endif

# Permissions & Feature flags
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/etc/permissions/android.software.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.xml \
    frameworks/native/data/etc/android.software.cts.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.cts.xml \
    frameworks/native/data/etc/android.software.app_widgets.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.app_widgets.xml \
    frameworks/native/data/etc/android.software.backup.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.backup.xml \
    frameworks/native/data/etc/android.software.voice_recognizers.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.voice_recognizers.xml \
    frameworks/native/data/etc/android.hardware.ethernet.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.ethernet.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.software.print.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.print.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.software.device_admin.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.device_admin.xml \
    frameworks/native/data/etc/android.hardware.keystore.app_attest_key.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.keystore.app_attest_key.xml

# Properties
PRODUCT_VENDOR_PROPERTIES += \
    ro.soc.manufacturer=Qualcomm \
    ro.soc.model=SC7180 \
    persist.sys.zram_enabled=1 \
    debug.stagefright.c2inputsurface=-1

# Host tools
PRODUCT_HOST_PACKAGES := \
    dtc \
    fdtoverlay \
    mkbootimg

# Page size support
PRODUCT_MAX_PAGE_SIZE_SUPPORTED := 16384
PRODUCT_NO_BIONIC_PAGE_SIZE_MACRO := true

# Default timezone and locale
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.timezone=America/New_York \
    persist.sys.timezone_confidence=100 \
    persist.sys.country=US \
    persist.sys.language=en \
    ro.product.locale=en-US

# Product properties
TARGET_PRODUCT_PROP := $(DEVICE_PATH)/product.prop

# VINTF Manifest
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml

# VINTF Kernel Requirements (permit 6.18 kernel on Android 16)
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false
PRODUCT_SHIPPING_API_LEVEL := 36
TARGET_HARDWARE := trogdor

# Inherit from vendor blobs if available
$(call inherit-product-if-exists, vendor/google/trogdor/trogdor-vendor.mk)
