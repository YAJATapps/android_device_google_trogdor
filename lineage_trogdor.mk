#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# Inherit tablet common Lineage configurations (Wi-Fi only, no telephony/modem)
$(call inherit-product, vendor/lineage/config/common_full_tablet_wifionly.mk)

# Inherit device configuration
$(call inherit-product, device/google/trogdor/device.mk)

# Device identifier
PRODUCT_NAME := lineage_trogdor
PRODUCT_DEVICE := trogdor
PRODUCT_BRAND := Google
PRODUCT_MODEL := Trogdor
PRODUCT_MANUFACTURER := Google

PRODUCT_CHARACTERISTICS := tablet,nosdcard
