#!/system/bin/sh
#
# Userdata expander for Google Trogdor
# Expands partition 5 (userdata) to claim 100% of the drive capacity.
#

LOG_FILE="/metadata/expand_userdata.log"
exec >> "$LOG_FILE" 2>&1

log() {
    echo "[expand_userdata] $*"
    echo "[expand_userdata] $*" > /dev/kmsg 2>/dev/null || true
}

log "Started at $(date)"

# 1. Determine the root disk and userdata partition
# First attempt: derive from mounted /metadata (partition 3 on the same disk)
META_DEV=$(grep -w "/metadata" /proc/mounts 2>/dev/null | awk '{print $1}')
DISK=""
PART="5"
USERDATA_DEV=""

if [ -n "$META_DEV" ] && [ -b "$META_DEV" ]; then
    META_BASE=$(basename "$META_DEV")
    case "$META_BASE" in
        mmcblk*p*|nvme*p*)
            DISK="/dev/block/${META_BASE%p*}"
            USERDATA_DEV="${DISK}p5"
            ;;
        sd[a-z][0-9]*)
            DISK="/dev/block/$(echo "$META_BASE" | sed -E 's/[0-9]+$//')"
            USERDATA_DEV="${DISK}5"
            ;;
    esac
fi

# Fallback: by-name symlink
if [ -z "$USERDATA_DEV" ] || [ ! -b "$USERDATA_DEV" ]; then
    for i in 1 2 3 4 5; do
        USERDATA_DEV=$(readlink -f /dev/block/by-name/userdata 2>/dev/null)
        if [ -n "$USERDATA_DEV" ] && [ -b "$USERDATA_DEV" ]; then
            break
        fi
        sleep 0.5
    done
fi

if [ -z "$DISK" ] && [ -n "$USERDATA_DEV" ] && [ -b "$USERDATA_DEV" ]; then
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
    esac
fi

log "Detected DISK=$DISK, PART=$PART, USERDATA_DEV=$USERDATA_DEV"

if [ -z "$DISK" ] || [ ! -b "$DISK" ] || [ -z "$USERDATA_DEV" ] || [ ! -b "$USERDATA_DEV" ]; then
    log "ERROR: Target block devices not found. Aborting."
    exit 1
fi

DISK_NAME=$(basename "$DISK")
USERDATA_NAME=$(basename "$USERDATA_DEV")

CURR_PART_SECTORS=$(cat "/sys/class/block/${USERDATA_NAME}/size" 2>/dev/null)
TOTAL_DISK_SECTORS=$(cat "/sys/class/block/${DISK_NAME}/size" 2>/dev/null)
START_SECTOR=$(cat "/sys/class/block/${USERDATA_NAME}/start" 2>/dev/null)

log "CURR_PART_SECTORS=$CURR_PART_SECTORS, TOTAL_DISK_SECTORS=$TOTAL_DISK_SECTORS, START_SECTOR=$START_SECTOR"

if [ -z "$CURR_PART_SECTORS" ] || [ -z "$TOTAL_DISK_SECTORS" ] || [ -z "$START_SECTOR" ]; then
    log "ERROR: Unable to read partition geometry from sysfs. Aborting."
    exit 1
fi

# Check if already expanded to drive capacity (within 4MB margin)
TARGET_MIN_SECTORS=$(( TOTAL_DISK_SECTORS - START_SECTOR - 8192 ))
if [ "$CURR_PART_SECTORS" -ge "$TARGET_MIN_SECTORS" ]; then
    log "Userdata is already fully expanded ($CURR_PART_SECTORS sectors). Nothing to do."
    exit 0
fi

log "Expanding userdata from $CURR_PART_SECTORS to fill disk ($TOTAL_DISK_SECTORS total sectors)..."

# 2. Relocate secondary GPT header to end of physical disk
# Android's sgdisk build requires long options (--move-second-header)
log "Running sgdisk --move-second-header $DISK..."
/system/bin/sgdisk --move-second-header "$DISK"

# 3. Read PARTUUID to preserve it
PARTUUID=$(/system/bin/sgdisk --info="$PART" "$DISK" 2>/dev/null | grep -i "Partition unique GUID" | awk '{print $NF}')
log "Preserving PARTUUID=$PARTUUID"

# 4. Recreate partition with fixed start sector extending to disk end
log "Recreating partition $PART: start=$START_SECTOR, end=0..."
if [ -n "$PARTUUID" ]; then
    /system/bin/sgdisk --delete="$PART" --new="${PART}:${START_SECTOR}:0" --partition-guid="${PART}:${PARTUUID}" --change-name="${PART}:userdata" "$DISK"
else
    /system/bin/sgdisk --delete="$PART" --new="${PART}:${START_SECTOR}:0" --change-name="${PART}:userdata" "$DISK"
fi

# 5. Determine new sector count and byte count
END_SECTOR=$(/system/bin/sgdisk --info="$PART" "$DISK" 2>/dev/null | grep -i "Last sector" | awk '{print $3}')
log "New GPT partition 5 end sector: $END_SECTOR"

if [ -n "$END_SECTOR" ] && [ "$END_SECTOR" -gt "$START_SECTOR" ]; then
    NEW_SECTORS=$(( END_SECTOR - START_SECTOR + 1 ))
    START_BYTES=$(( START_SECTOR * 512 ))
    LENGTH_BYTES=$(( NEW_SECTORS * 512 ))

    # 6. Inform kernel live via BLKPG_RESIZE_PARTITION
    if [ -x /vendor/bin/blkpg_resize ]; then
        log "Calling blkpg_resize $DISK $PART $START_BYTES $LENGTH_BYTES..."
        /vendor/bin/awk -v d="$DISK" -v p="$PART" -v s="$START_SECTOR" -v n="$NEW_SECTORS" 'BEGIN { cmd = sprintf("/vendor/bin/blkpg_resize %s %s %.0f %.0f", d, p, s * 512, n * 512); exit system(cmd); }'
    else
        log "WARNING: /vendor/bin/blkpg_resize not found or not executable!"
    fi
fi

# 7. Resize filesystem offline while unmounted
sleep 0.5
log "Resizing F2FS filesystem on $USERDATA_DEV..."
if [ -x /system/bin/resize.f2fs ]; then
    echo y | /system/bin/resize.f2fs "$USERDATA_DEV"
elif [ -x /system/bin/resize2fs ]; then
    /system/bin/resize2fs "$USERDATA_DEV"
fi

log "Userdata expansion complete at $(date)."
exit 0
