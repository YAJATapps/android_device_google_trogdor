#!/system/bin/sh
#
# One-time first boot userdata expander for Google Trogdor
# Expands partition 5 (userdata) to claim 100% of the drive capacity.
#

FLAG="/metadata/.userdata_expanded"
if [ -f "$FLAG" ]; then
    exit 0
fi

# Find the real block device path for userdata (e.g. /dev/block/sda5 or /dev/block/mmcblk1p5)
USERDATA_DEV=$(readlink -f /dev/block/by-name/userdata 2>/dev/null)
if [ -z "$USERDATA_DEV" ] || [ ! -b "$USERDATA_DEV" ]; then
    exit 0
fi

# Extract parent disk and partition number
DEV_BASE=$(basename "$USERDATA_DEV")
case "$DEV_BASE" in
    mmcblk*p*|nvme*p*)
        DISK="/dev/block/${DEV_BASE%p*}"
        PART="${DEV_BASE##*p}"
        ;;
    sd[a-z][0-9]*)
        DISK="/dev/block/$(echo "$DEV_BASE" | sed -E 's/[0-9]+$//')"
        PART=$(echo "$DEV_BASE" | grep -oE '[0-9]+$')
        ;;
    *)
        DISK=""
        PART=""
        ;;
esac

if [ -n "$DISK" ] && [ -b "$DISK" ] && [ -n "$PART" ]; then
    # 1. Move backup GPT header to true end of the physical disk
    /system/bin/sgdisk -e "$DISK" >/dev/null 2>&1 || true

    # 2. Extend partition 5 to the end of the disk
    /system/bin/sgdisk -d "$PART" -n "${PART}:0:0" -c "${PART}:userdata" "$DISK" >/dev/null 2>&1 || true

    # 3. Inform kernel to re-read partition table
    /system/bin/blockdev --rereadpt "$DISK" >/dev/null 2>&1 || true
fi

# Mark completed so this script never runs again
touch "$FLAG"
