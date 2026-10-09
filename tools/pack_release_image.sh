#!/usr/bin/env bash
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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_TOP="${ANDROID_BUILD_TOP:-$(cd "$DEVICE_DIR/../../.." && pwd)}"
PRODUCT_OUT="${PRODUCT_OUT:-$BUILD_TOP/out/target/product/trogdor}"
HOST_OUT="${ANDROID_HOST_OUT:-$BUILD_TOP/out/host/linux-x86}"

SUPER_SPARSE="$PRODUCT_OUT/super.img"
SUPER_RAW="$PRODUCT_OUT/super.raw.img"
VMLINUZ_KPART="$PRODUCT_OUT/vmlinuz.kpart"
SIMG2IMG="$HOST_OUT/bin/simg2img"

RELEASE_NAME="lineage-23.2-trogdor-$(date +%Y%m%d)"
RAW_IMG="$PRODUCT_OUT/${RELEASE_NAME}.img"
XZ_IMG="$PRODUCT_OUT/${RELEASE_NAME}.img.xz"

WORK_DIR=$(mktemp -d -t trogdor_pack_XXXXXX)
trap "rm -rf '$WORK_DIR'" EXIT

echo "============================================================"
echo " LineageOS 23.2 Release Image Builder for Lenovo Duet 3"
echo " Board: Google Trogdor (Wormdingler, SC7180)"
echo "============================================================"

# 1. Check prerequisites
SGDISK="$(command -v /usr/sbin/sgdisk || command -v sgdisk || true)"
CGPT="$(command -v /usr/bin/cgpt || command -v cgpt || true)"

for tool in mke2fs xz; do
    if ! command -v "$tool" &>/dev/null; then
        echo "[-] ERROR: Required tool '$tool' not found. Please install it (e.g. sudo apt install e2fsprogs xz-utils)." >&2
        exit 1
    fi
done

if [ -z "$SGDISK" ]; then
    echo "[-] ERROR: sgdisk not found. Please install gdisk (sudo apt install gdisk)." >&2
    exit 1
fi

if [ -z "$CGPT" ]; then
    echo "[-] ERROR: cgpt not found. Please install cgpt (sudo apt install cgpt)." >&2
    exit 1
fi

if [ ! -f "$SIMG2IMG" ]; then
    echo "[-] ERROR: simg2img host tool not found at '$SIMG2IMG'. Please build it via: m simg2img" >&2
    exit 1
fi

if [ ! -f "$SUPER_SPARSE" ]; then
    echo "[-] ERROR: super.img not found at '$SUPER_SPARSE'. Please build it via: m superimage" >&2
    exit 1
fi

# 2. Build or verify vmlinuz.kpart
if [ ! -f "$VMLINUZ_KPART" ] || [ "$VMLINUZ_KPART" -ot "$PRODUCT_OUT/kernel" ]; then
    echo "[*] Packaging ChromeOS Depthcharge kernel (vmlinuz.kpart)..."
    "$SCRIPT_DIR/pack_kpart.sh"
fi

if [ ! -f "$VMLINUZ_KPART" ]; then
    echo "[-] ERROR: Failed to generate '$VMLINUZ_KPART'" >&2
    exit 1
fi

# 3. Convert sparse super.img to raw super.raw.img if needed
if [ ! -f "$SUPER_RAW" ] || [ "$SUPER_RAW" -ot "$SUPER_SPARSE" ]; then
    echo "[*] Converting sparse super.img to raw unsparse image (simg2img)..."
    "$SIMG2IMG" "$SUPER_SPARSE" "$SUPER_RAW"
fi

SUPER_SIZE_BYTES=$(stat -c%s "$SUPER_RAW")
SUPER_SIZE_SECTORS=$(( SUPER_SIZE_BYTES / 512 ))

# Check that super size matches expected alignment
if [ $(( SUPER_SIZE_BYTES % 512 )) -ne 0 ]; then
    echo "[-] ERROR: super.raw.img size ($SUPER_SIZE_BYTES) is not sector-aligned!" >&2
    exit 1
fi

echo "[+] super.raw.img size: $SUPER_SIZE_BYTES bytes ($SUPER_SIZE_SECTORS sectors)"

# 4. Partition Geometry Definition (512-byte sectors, 1 MB aligned)
# Clean Architecture:
#   p1: misc      (16 MB  =    32,768 sectors) -> Raw BCB block
#   p2: KERN-A    (64 MB  =   131,072 sectors) -> ChromeOS vboot Depthcharge kernel
#   p3: metadata  (16 MB  =    32,768 sectors) -> ext4 FBE encryption keys
#   p4: super     (dynamic sectors based on super.raw.img) -> Android OS container
#   p5: userdata  (initial ~3.5 GB for 16 GB base image) -> Android /data

P1_START=2048
P1_SIZE=32768
P1_END=$(( P1_START + P1_SIZE - 1 )) # 34815

P2_START=$(( P1_END + 1 )) # 34816
P2_SIZE=131072
P2_END=$(( P2_START + P2_SIZE - 1 )) # 165887

P3_START=$(( P2_END + 1 )) # 165888
P3_SIZE=32768
P3_END=$(( P3_START + P3_SIZE - 1 )) # 198655

P4_START=$(( P3_END + 1 )) # 198656
P4_SIZE=$SUPER_SIZE_SECTORS
P4_END=$(( P4_START + P4_SIZE - 1 ))

# Userdata starts right after super aligned to 1MB (2048 sectors)
P5_START=$(( (P4_END + 2048) / 2048 * 2048 ))
# Initial image size: 15.5 GB total (~32,505,856 sectors, fits easily on any 16GB+ drive)
TOTAL_SECTORS=32505856
P5_END=$(( TOTAL_SECTORS - 34 )) # leave 33 sectors for secondary GPT table + 1 for header

echo "[*] Creating raw disk image container ($TOTAL_SECTORS sectors / ~15.5 GB)..."
rm -f "$RAW_IMG"
truncate -s $(( TOTAL_SECTORS * 512 )) "$RAW_IMG"

echo "[*] Writing clean GPT partition table..."
"$SGDISK" \
    --zap-all \
    --new="1:${P1_START}:${P1_END}" --change-name="1:misc" --typecode="1:8300" \
    --new="2:${P2_START}:${P2_END}" --change-name="2:KERN-A" --typecode="2:FE3A2A5D-4F32-41A7-B725-ACCC3285A309" \
    --new="3:${P3_START}:${P3_END}" --change-name="3:metadata" --typecode="3:8300" \
    --new="4:${P4_START}:${P4_END}" --change-name="4:super" --typecode="4:8300" \
    --new="5:${P5_START}:${P5_END}" --change-name="5:userdata" --typecode="5:8300" \
    "$RAW_IMG"

echo "[*] Setting ChromeOS Depthcharge bootloader flags on KERN-A..."
"$CGPT" add -i 2 -P 15 -T 15 -S 1 "$RAW_IMG"

echo "[*] Creating formatted metadata ext4 filesystem..."
METADATA_IMG="$WORK_DIR/metadata.img"
mke2fs -q -F -t ext4 -b 4096 -L metadata -O "^has_journal" "$METADATA_IMG" $(( P3_SIZE * 512 / 1024 ))k

echo "[*] Burning KERN-A (vmlinuz.kpart) into partition 2..."
dd if="$VMLINUZ_KPART" of="$RAW_IMG" bs=1M seek=$(( P2_START / 2048 )) conv=notrunc status=none

echo "[*] Burning metadata into partition 3..."
dd if="$METADATA_IMG" of="$RAW_IMG" bs=1M seek=$(( P3_START / 2048 )) conv=notrunc status=none

echo "[*] Burning super.raw.img into partition 4..."
dd if="$SUPER_RAW" of="$RAW_IMG" bs=1M seek=$(( P4_START / 2048 )) conv=notrunc status=progress

echo "[*] Partition table verification:"
"$CGPT" show "$RAW_IMG"

echo "============================================================"
echo "[*] Compressing disk image with multi-threaded XZ..."
echo "    Output file: $XZ_IMG"
echo "============================================================"
xz -T0 -8 -f "$RAW_IMG"

echo ""
echo "============================================================"
echo " [SUCCESS] Release image built successfully!"
echo " Image: $XZ_IMG"
echo " Size:  $(du -h "$XZ_IMG" | awk '{print $1}')"
echo " "
echo " How to use:"
echo " 1. Flash to USB stick or SD card with balenaEtcher or Rufus."
echo " 2. Boot on Chromebook in Developer Mode with Ctrl + U."
echo "============================================================"
