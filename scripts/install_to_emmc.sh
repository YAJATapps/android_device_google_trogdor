#!/system/bin/sh
#
# Standalone LineageOS Internal Storage (eMMC / NVMe) Installer
# Designed for Google Trogdor (SC7180) Chromebooks
#
set -e

LOG_FILE="/metadata/install.log"
rm -f "$LOG_FILE" 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || true
chmod 644 "$LOG_FILE" 2>/dev/null || true

log_msg() {
    echo "$1"
    echo "$1" >> "$LOG_FILE" 2>/dev/null || true
}

set_progress() {
    PCT="$1"
    MSG="$2"
    log_msg "$MSG"
    /system/bin/setprop vendor.installer.percent "$PCT" 2>/dev/null || true
    /system/bin/setprop vendor.installer.status "$MSG" 2>/dev/null || true
}

on_exit() {
    EXIT_CODE=$?
    if [ "$EXIT_CODE" -ne 0 ]; then
        log_msg "[-] ERROR: Installation failed with exit status $EXIT_CODE"
        /system/bin/setprop vendor.installer.state "failed" 2>/dev/null || true
    fi
}
trap on_exit EXIT

/system/bin/setprop vendor.installer.state "running" 2>/dev/null || true
/system/bin/setprop vendor.installer.percent "0" 2>/dev/null || true

log_msg "============================================================"
log_msg " LineageOS Internal Storage Installer (Google Trogdor)"
log_msg "============================================================"

# 1. Identify booted drive (Live USB)
BOOT_DEV=""
for mount_point in /metadata /data; do
    DEV=$(grep -w "$mount_point" /proc/mounts 2>/dev/null | awk '{print $1}')
    if [ -n "$DEV" ] && [ -b "$DEV" ]; then
        BASE=$(basename "$DEV")
        case "$BASE" in
            mmcblk*p*|nvme*p*)
                BOOT_DEV="/dev/block/${BASE%p*}"
                ;;
            sd[a-z][0-9]*)
                BOOT_DEV="/dev/block/$(echo "$BASE" | sed -E 's/[0-9]+$//')"
                ;;
        esac
        break
    fi
done

if [ -z "$BOOT_DEV" ] || [ ! -b "$BOOT_DEV" ]; then
    BOOT_DEV="/dev/block/sda"
fi

log_msg "[+] Boot source (Live USB): $BOOT_DEV"

# 2. Identify target internal storage (eMMC or NVMe)
TARGET_DEV=""

# Check if target was requested via system property or file
REQ_TARGET=$(/system/bin/getprop vendor.installer.target 2>/dev/null | tr -d ' \r\n')
if [ -z "$REQ_TARGET" ] && [ -s /data/local/tmp/install_target ]; then
    REQ_TARGET=$(cat /data/local/tmp/install_target 2>/dev/null | tr -d ' \r\n')
fi

if [ -n "$REQ_TARGET" ]; then
    case "$REQ_TARGET" in
        /dev/block/*) CAND_DEV="$REQ_TARGET" ;;
        *) CAND_DEV="/dev/block/$REQ_TARGET" ;;
    esac
    if [ -b "$CAND_DEV" ] && [ "$CAND_DEV" != "$BOOT_DEV" ]; then
        TARGET_DEV="$CAND_DEV"
        log_msg "[+] Using requested target drive: $TARGET_DEV"
    fi
fi

if [ -z "$TARGET_DEV" ]; then
    for cand in /dev/block/mmcblk1 /dev/block/mmcblk0 /dev/block/nvme0n1; do
        if [ -b "$cand" ] && [ "$cand" != "$BOOT_DEV" ]; then
            TARGET_DEV="$cand"
            break
        fi
    done
fi

# Fallback: check sysfs block devices
if [ -z "$TARGET_DEV" ]; then
    for node in /sys/class/block/*; do
        [ -e "$node" ] || continue
        NAME=$(basename "$node")
        case "$NAME" in
            loop*|ram*|dm-*|zram*|mtd*|*boot*|*rpmb*) continue ;;
            sd[a-z][0-9]*|*p[0-9]*) continue ;;
            *)
                if [ "/dev/block/$NAME" != "$BOOT_DEV" ] && [ -b "/dev/block/$NAME" ]; then
                    TARGET_DEV="/dev/block/$NAME"
                    break
                fi
                ;;
        esac
    done
fi

if [ -z "$TARGET_DEV" ] || [ ! -b "$TARGET_DEV" ]; then
    log_msg "[-] ERROR: Internal storage target could not be detected!"
    exit 1
fi

DST_NAME=$(basename "$TARGET_DEV")
TOTAL_SECTORS=$(cat "/sys/class/block/${DST_NAME}/size" 2>/dev/null || echo 0)
TOTAL_GB=$(( TOTAL_SECTORS / 2097152 ))

log_msg "[+] Target internal drive:  $TARGET_DEV (~${TOTAL_GB} GB, ${TOTAL_SECTORS} sectors)"

if [ "$TOTAL_SECTORS" -lt 30000000 ]; then
    log_msg "[-] ERROR: Target drive size is under 15GB. Aborting."
    exit 1
fi

# 3. Determine partition paths
case "$BOOT_DEV" in
    *mmcblk*|*nvme*) SP1="${BOOT_DEV}p1"; SP2="${BOOT_DEV}p2"; SP3="${BOOT_DEV}p3"; SP4="${BOOT_DEV}p4"; SP5="${BOOT_DEV}p5" ;;
    *)               SP1="${BOOT_DEV}1";  SP2="${BOOT_DEV}2";  SP3="${BOOT_DEV}3";  SP4="${BOOT_DEV}4";  SP5="${BOOT_DEV}5" ;;
esac

case "$TARGET_DEV" in
    *mmcblk*|*nvme*) DP1="${TARGET_DEV}p1"; DP2="${TARGET_DEV}p2"; DP3="${TARGET_DEV}p3"; DP4="${TARGET_DEV}p4"; DP5="${TARGET_DEV}p5" ;;
    *)               DP1="${TARGET_DEV}1";  DP2="${TARGET_DEV}2";  DP3="${TARGET_DEV}3";  DP4="${TARGET_DEV}4";  DP5="${TARGET_DEV}5" ;;
esac

set_progress 10 "Step 1/5: Partitioning internal drive ($TARGET_DEV)..."
/system/bin/sgdisk --zap-all "$TARGET_DEV" >> "$LOG_FILE" 2>&1

SUPER_SECTORS=$(cat "/sys/class/block/$(basename "$SP4")/size" 2>/dev/null || echo 24297472)
P4_START=204800
P4_END=$(( P4_START + SUPER_SECTORS - 1 ))
P5_START=$(( P4_END + 1 ))
P5_END=$(( TOTAL_SECTORS - 34 ))

/system/bin/sgdisk \
    --new="1:8192:40959" --change-name="1:misc" --typecode="1:8300" \
    --new="2:40960:172031" --change-name="2:KERN-A" --typecode="2:FE3A2A5D-4F32-41A7-B725-ACCC3285A309" \
    --new="3:172032:204799" --change-name="3:metadata" --typecode="3:8300" \
    --new="4:${P4_START}:${P4_END}" --change-name="4:super" --typecode="4:8300" \
    --new="5:${P5_START}:${P5_END}" --change-name="5:userdata" --typecode="5:8300" \
    "$TARGET_DEV" >> "$LOG_FILE" 2>&1

# Depthcharge kernel boot priority (Priority=15, Tries=15, Successful=1)
/system/bin/sgdisk --attributes=2:set:48 --attributes=2:set:49 --attributes=2:set:50 --attributes=2:set:51 \
                   --attributes=2:set:52 --attributes=2:set:53 --attributes=2:set:54 --attributes=2:set:55 \
                   --attributes=2:set:56 "$TARGET_DEV" >> "$LOG_FILE" 2>&1 || true

/system/bin/blockdev --rereadpt "$TARGET_DEV" 2>/dev/null || true
sleep 1

set_progress 25 "Step 2/5: Copying ChromeOS Kernel ($SP2 -> $DP2)..."
dd if="$SP2" of="$DP2" bs=4M conv=fsync >> "$LOG_FILE" 2>&1

set_progress 35 "Step 3/5: Initializing clean metadata partition ($DP3)..."
if [ -x /system/bin/mke2fs ]; then
    /system/bin/mke2fs -F -q -t ext4 -b 4096 -L metadata "$DP3" >> "$LOG_FILE" 2>&1 || dd if=/dev/zero of="$DP3" bs=4M count=4 conv=fsync >> "$LOG_FILE" 2>&1
else
    dd if=/dev/zero of="$DP3" bs=4M count=4 conv=fsync >> "$LOG_FILE" 2>&1
fi

set_progress 45 "Step 4/5: Copying Android system container (~11.6 GB)..."
dd if="$SP4" of="$DP4" bs=4M conv=fsync >> "$LOG_FILE" 2>&1 &
DD_PID=$!
DP4_NAME=$(basename "$DP4")

while kill -0 "$DD_PID" 2>/dev/null; do
    sleep 2
    if [ -f "/sys/class/block/${DP4_NAME}/stat" ]; then
        read -r _ _ _ _ _ _ WRITTEN_SECTORS _ < "/sys/class/block/${DP4_NAME}/stat" 2>/dev/null || WRITTEN_SECTORS=0
        if [ "$WRITTEN_SECTORS" -gt 0 ] && [ "$SUPER_SECTORS" -gt 0 ]; then
            PCT=$(( 45 + (WRITTEN_SECTORS * 40 / SUPER_SECTORS) ))
            [ "$PCT" -gt 84 ] && PCT=84
            /system/bin/setprop vendor.installer.percent "$PCT" 2>/dev/null || true
            MB_WRITTEN=$(( WRITTEN_SECTORS / 2048 ))
            TOTAL_MB=$(( SUPER_SECTORS / 2048 ))
            /system/bin/setprop vendor.installer.status "Copying system: ${MB_WRITTEN} MB / ${TOTAL_MB} MB..." 2>/dev/null || true
        fi
    fi
done

wait "$DD_PID"

set_progress 88 "Step 5/5: Pre-formatting userdata on internal storage ($DP5)..."
if [ -x /system/bin/make_f2fs ]; then
    /system/bin/make_f2fs -f -q -g android -O encrypt,extra_attr,project_quota,quota,compression -l data "$DP5" >> "$LOG_FILE" 2>&1
else
    dd if=/dev/zero of="$DP5" bs=4M count=8 conv=fsync >> "$LOG_FILE" 2>&1
fi

set_progress 95 "Finalizing PMBR and syncing disks..."
# Preserve PMBR protective boot record
dd if="$BOOT_DEV" of="$TARGET_DEV" bs=1 count=16 skip=446 seek=446 conv=notrunc >> "$LOG_FILE" 2>&1 || true
sync

set_progress 100 "Installation Complete!"
/system/bin/setprop vendor.installer.state "success" 2>/dev/null || true

log_msg ""
log_msg "============================================================"
log_msg " [SUCCESS] LineageOS installed to internal storage!"
log_msg " 1. Power off or unplug the USB flash drive."
log_msg " 2. Boot your Chromebook normally with Ctrl + D or Ctrl + U."
log_msg "============================================================"
exit 0
