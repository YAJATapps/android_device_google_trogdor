#!/system/bin/sh
# Ensure /dev/block/by-name/misc exists for BootControl HAL (android.hardware.boot-service)
if [ ! -e /dev/block/by-name/misc ]; then
    mkdir -p /dev/block/by-name
    MISC_DEV=""
    for dev in /dev/block/sda5 /dev/block/sdb5 /dev/block/sdc5 /dev/block/mmcblk0p5 /dev/block/mmcblk1p5; do
        if [ -b "$dev" ]; then
            MISC_DEV="$dev"
            break
        fi
    done
    if [ -n "$MISC_DEV" ]; then
        /system/bin/ln -sf "$MISC_DEV" /dev/block/by-name/misc
        /system/bin/chmod 600 /dev/block/by-name/misc
    else
        if [ ! -f /metadata/misc.img ]; then
            /system/bin/dd if=/dev/zero of=/metadata/misc.img bs=1M count=4
        fi
        LOOP_DEV=$(/system/bin/losetup -fs /metadata/misc.img 2>/dev/null)
        if [ -n "$LOOP_DEV" ]; then
            /system/bin/ln -sf "$LOOP_DEV" /dev/block/by-name/misc
            /system/bin/chmod 600 /dev/block/by-name/misc
        fi
    fi
fi
