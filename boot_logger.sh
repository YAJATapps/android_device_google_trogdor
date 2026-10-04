#!/system/bin/sh
# Continuous boot logger to USB /metadata/logs

LOG_DIR="/metadata/logs"
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Ensure /dev/block/by-name/misc exists for BootControl HAL (android.hardware.boot-service)
if [ ! -e /dev/block/by-name/misc ]; then
    mkdir -p /dev/block/by-name
    if [ ! -f /metadata/misc.img ]; then
        /system/bin/dd if=/dev/zero of=/metadata/misc.img bs=1M count=4
    fi
    LOOP_DEV=$(/system/bin/losetup -fs /metadata/misc.img 2>/dev/null)
    if [ -n "$LOOP_DEV" ]; then
        /system/bin/ln -sf "$LOOP_DEV" /dev/block/by-name/misc
        /system/bin/chmod 600 /dev/block/by-name/misc
    fi
fi

# 1. Immediate snapshot of dmesg
/system/bin/dmesg > "$LOG_DIR/dmesg_boot.txt" 2>&1
sync

# 2. Continuous kernel stream from /proc/kmsg
/system/bin/cat /proc/kmsg >> "$LOG_DIR/dmesg_continuous.txt" 2>&1 &

# 3. Continuous Android logcat stream
/system/bin/logcat -b all -v time -f "$LOG_DIR/logcat.txt" 2>&1 &

# 4. Periodically flush buffers to physical USB disk
while true; do
    sleep 5
    sync
done
