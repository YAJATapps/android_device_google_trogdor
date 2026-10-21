#!/bin/bash
set -e

# Determine Android build root
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TOP="${ANDROID_BUILD_TOP:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

# external/dng_sdk
if [ -f "$TOP/external/dng_sdk/Android.bp" ]; then
    echo "Patching external/dng_sdk: removing vendor_available..."
    sed -i '/vendor_available: true,/d' "$TOP/external/dng_sdk/Android.bp"
fi

# external/libjxl
if [ -f "$TOP/external/libjxl/Android.bp" ]; then
    echo "Patching external/libjxl: removing vendor_available..."
    sed -i '/vendor_available: true,/d' "$TOP/external/libjxl/Android.bp"
fi

# packages/apps/SetupWizard
SUW_KT="$TOP/packages/apps/SetupWizard/app/src/main/java/org/lineageos/setupwizard/WelcomeActivity.kt"
SUW_JAVA="$TOP/packages/apps/SetupWizard/src/org/lineageos/setupwizard/WelcomeActivity.java"
if [ -f "$SUW_KT" ]; then
    echo "Patching packages/apps/SetupWizard: auto-finishing setup on boot (Kotlin)..."
    sed -i 's/get() = Build.TYPE == "eng"/get() = true/' "$SUW_KT"
    if ! grep -q "finishSetupWizard(this)" "$SUW_KT"; then
        sed -i '/super.onCreate(savedInstanceState)/a \        if (!isFinishing) { SetupWizardUtils.finishSetupWizard(this); return }' "$SUW_KT"
    fi
elif [ -f "$SUW_JAVA" ]; then
    echo "Patching packages/apps/SetupWizard: auto-finishing setup on boot..."
    sed -i 's/if (Build.TYPE.equals("eng"))/SetupWizardUtils.finishSetupWizard(this); if (false)/' "$SUW_JAVA"
fi

SUW_ACT_KT="$TOP/packages/apps/SetupWizard/app/src/main/java/org/lineageos/setupwizard/SetupWizardActivity.kt"
SUW_ACT_JAVA="$TOP/packages/apps/SetupWizard/src/org/lineageos/setupwizard/SetupWizardActivity.java"
if [ -f "$SUW_ACT_KT" ]; then
    echo "Patching packages/apps/SetupWizard: disabling forced gesture navigation (Kotlin)..."
    sed -i 's/^[[:space:]]*SetupWizardUtils.enableGesturalNavigation(this)/\/\/ SetupWizardUtils.enableGesturalNavigation(this)/' "$SUW_ACT_KT"
elif [ -f "$SUW_ACT_JAVA" ]; then
    echo "Patching packages/apps/SetupWizard: disabling forced gesture navigation..."
    sed -i 's/^[[:space:]]*SetupWizardUtils.enableGesturalNavigation(this);/\/\/ SetupWizardUtils.enableGesturalNavigation(this);/' "$SUW_ACT_JAVA"
fi

# system/vold: C++23 missing <algorithm> header for std::replace
VOLD_PUBLIC_VOL="$TOP/system/vold/model/PublicVolume.cpp"
if [ -f "$VOLD_PUBLIC_VOL" ] && ! grep -q "#include <algorithm>" "$VOLD_PUBLIC_VOL"; then
    echo "Patching system/vold: adding missing <algorithm> header for C++23..."
    sed -i '/#include "PublicVolume.h"/a #include <algorithm>' "$VOLD_PUBLIC_VOL"
fi

# bootable/recovery: C++23 missing <algorithm> and <vector> headers
RECOVERY_PUBLIC_VOL="$TOP/bootable/recovery/volume_manager/PublicVolume.cpp"
if [ -f "$RECOVERY_PUBLIC_VOL" ] && ! grep -q "#include <algorithm>" "$RECOVERY_PUBLIC_VOL"; then
    echo "Patching bootable/recovery: adding missing <algorithm> header for C++23..."
    sed -i '/#include "PublicVolume.h"/a #include <algorithm>' "$RECOVERY_PUBLIC_VOL"
fi

RECOVERY_VOL_MGR="$TOP/bootable/recovery/volume_manager/include/volume_manager/VolumeManager.h"
if [ -f "$RECOVERY_VOL_MGR" ] && ! grep -q "#include <vector>" "$RECOVERY_VOL_MGR"; then
    echo "Patching bootable/recovery: adding missing <vector> header for C++23..."
    sed -i '/#include <string>/a #include <vector>' "$RECOVERY_VOL_MGR"
fi

# frameworks/base: NotificationAttentionHelper NPE when mLineageNotificationLights is null
NMS_ATTENTION_HELPER="$TOP/frameworks/base/services/core/java/com/android/server/notification/NotificationAttentionHelper.java"
if [ -f "$NMS_ATTENTION_HELPER" ] && ! grep -q "mLineageNotificationLights != null && !mLineageNotificationLights.showLightsScreenOn()" "$NMS_ATTENTION_HELPER"; then
    echo "Patching frameworks/base: fixing mLineageNotificationLights NPE in NotificationAttentionHelper..."
    sed -i 's/if (!mLineageNotificationLights\.showLightsScreenOn())/if (mLineageNotificationLights != null \&\& !mLineageNotificationLights.showLightsScreenOn())/g' "$NMS_ATTENTION_HELPER"
fi

# hardware/lineage/interfaces/light: add dp_aux_backlight for eDP panels (e.g. Lenovo Duet 5)
LIGHT_DEVICES="$TOP/hardware/lineage/interfaces/light/Devices.cpp"
if [ -f "$LIGHT_DEVICES" ] && ! grep -q "dp_aux_backlight" "$LIGHT_DEVICES"; then
    echo "Patching hardware/lineage/interfaces/light: adding dp_aux_backlight to Devices.cpp..."
    sed -i 's/"panel0-backlight-ex",/"panel0-backlight-ex",\n        "dp_aux_backlight",/' "$LIGHT_DEVICES"
fi

LIGHT_RC="$TOP/hardware/lineage/interfaces/light/android.hardware.light-service.lineage.rc"
if [ -f "$LIGHT_RC" ] && ! grep -q "dp_aux_backlight" "$LIGHT_RC"; then
    echo "Patching hardware/lineage/interfaces/light: adding dp_aux_backlight permissions to rc..."
    sed -i '/sprd_backlight\/max_brightness/a \\n    chown system system \/sys\/class\/backlight\/dp_aux_backlight\/brightness\n    chown system system \/sys\/class\/backlight\/dp_aux_backlight\/max_brightness' "$LIGHT_RC"
fi

echo "Patches applied successfully."
