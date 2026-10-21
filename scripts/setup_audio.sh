#!/system/bin/sh
#
# Setup board-specific audio policy configuration
#
# Lenovo IdeaPad Duet 5 (Homestar) routes Secondary MI2S across 2 serial data lines (SD0 and SD1)
# to drive 4 discrete MAX98360A speaker amplifiers in QUAD01 mode.
# The Qualcomm LPASS hardware driver requires 4 channels (AUDIO_CHANNEL_INDEX_MASK_4).
# When Homestar is detected via device-tree compatible, bind-mount the 4-channel
# audio policy configuration before audioserver / audio HAL starts.

if grep -q "google,homestar" /proc/device-tree/compatible 2>/dev/null; then
    echo "[setup_audio] Detected Lenovo Duet 5 (homestar). Applying 4-channel audio policy..." > /dev/kmsg 2>/dev/null || true
    mount --bind /vendor/etc/audio_policy_configuration_homestar.xml /vendor/etc/audio_policy_configuration.xml
fi

# Configure ALSA codec mixer controls for internal microphone (Realtek ALC5682)
# per upstream ChromeOS UCM topology
/system/bin/tinymix -D 0 "STO1 ADC Capture Switch" 1 1 2>/dev/null || true
/system/bin/tinymix -D 0 "IF1 01 ADC Swap Mux" 1 2>/dev/null || true
/system/bin/tinymix -D 0 "Stereo1 ADC L2 Mux" 1 2>/dev/null || true
/system/bin/tinymix -D 0 "Stereo1 ADC R2 Mux" 1 2>/dev/null || true
/system/bin/tinymix -D 0 "Stereo1 ADC MIXL ADC2 Switch" 1 2>/dev/null || true
/system/bin/tinymix -D 0 "Stereo1 ADC MIXR ADC2 Switch" 1 2>/dev/null || true
/system/bin/tinymix -D 0 "STO1 ADC Capture Volume" 50 50 2>/dev/null || true
/system/bin/tinymix -D 0 "STO1 ADC Boost Gain Volume" 2 2 2>/dev/null || true
