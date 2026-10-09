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

OUTPUT_TO_DESKTOP=false
COMPRESS_XZ=true

for arg in "$@"; do
    case "$arg" in
        --desktop)
            OUTPUT_TO_DESKTOP=true
            ;;
        --noxz)
            COMPRESS_XZ=false
            ;;
        -h|--help)
            echo "Usage: $0 [--desktop] [--noxz]"
            echo "  --desktop  Output final image to ~/Desktop instead of out/target/product/trogdor"
            echo "  --noxz     Skip .xz compression and output raw .img (super fast, ~5 sec build)"
            exit 0
            ;;
        *)
            echo "[-] ERROR: Unknown argument '$arg'" >&2
            echo "Usage: $0 [--desktop] [--noxz]" >&2
            exit 1
            ;;
    esac
done

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
DEST_DIR="$PRODUCT_OUT"
if [ "$OUTPUT_TO_DESKTOP" = true ]; then
    DEST_DIR="$HOME/Desktop"
fi
RAW_IMG="$PRODUCT_OUT/${RELEASE_NAME}.img"
XZ_IMG="$PRODUCT_OUT/${RELEASE_NAME}.img.xz"

WORK_DIR=$(mktemp -d -t trogdor_pack_XXXXXX)
trap "rm -rf '$WORK_DIR'" EXIT

echo "============================================================"
echo " LineageOS 23.2 Universal Release Image Builder"
echo " Platform: Qualcomm Snapdragon 7c (SC7180) Chromebooks"
echo " Family: Google Trogdor (Wormdingler, CoachZ, Lazor, Homun, etc.)"
if [ "$OUTPUT_TO_DESKTOP" = true ]; then
    echo " Target:   ~/Desktop"
fi
if [ "$COMPRESS_XZ" = false ]; then
    echo " Mode:     Raw uncompressed .img (--noxz)"
fi
echo "============================================================"

CGPT="$(command -v /usr/bin/cgpt || command -v cgpt || true)"

PREREQS="mke2fs"
if [ "$COMPRESS_XZ" = true ]; then
    PREREQS="$PREREQS xz"
fi

for tool in $PREREQS; do
    if ! command -v "$tool" &>/dev/null; then
        echo "[-] ERROR: Required tool '$tool' not found. Please install it (e.g. sudo apt install e2fsprogs xz-utils)." >&2
        exit 1
    fi
done

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

MAKE_F2FS="$HOST_OUT/bin/make_f2fs"
if [ ! -f "$MAKE_F2FS" ]; then
    echo "[-] ERROR: make_f2fs host tool not found at '$MAKE_F2FS'. Please build it via: m make_f2fs" >&2
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

# 4. Partition Geometry Definition (512-byte sectors, 4 MB / 8192 sectors aligned)
# Clean Architecture:
#   p1: misc      (16 MB  =    32,768 sectors) -> Raw BCB block
#   p2: KERN-A    (64 MB  =   131,072 sectors) -> ChromeOS vboot Depthcharge kernel
#   p3: metadata  (16 MB  =    32,768 sectors) -> ext4 FBE encryption keys
#   p4: super     (dynamic sectors based on super.raw.img) -> Android OS container
#   p5: userdata  (initial ~3.5 GB for 16 GB base image) -> Android /data

P1_START=8192
P1_SIZE=32768
P1_END=$(( P1_START + P1_SIZE - 1 )) # 40959

P2_START=$(( P1_END + 1 )) # 40960
P2_SIZE=131072
P2_END=$(( P2_START + P2_SIZE - 1 )) # 172031

P3_START=$(( P2_END + 1 )) # 172032
P3_SIZE=32768
P3_END=$(( P3_START + P3_SIZE - 1 )) # 204799

P4_START=$(( P3_END + 1 )) # 204800
P4_SIZE=$SUPER_SIZE_SECTORS
P4_END=$(( P4_START + P4_SIZE - 1 ))

# Userdata starts right after super aligned to 4MB (8192 sectors)
P5_START=$(( (P4_END + 8192) / 8192 * 8192 ))
# Initial image size: 15.5 GB total (~32,505,856 sectors, fits easily on any 16GB+ drive)
TOTAL_SECTORS=32505856
P5_END=$(( TOTAL_SECTORS - 34 )) # leave 33 sectors for secondary GPT table + 1 for header
P5_SIZE=$(( P5_END - P5_START + 1 ))

echo "[*] Creating raw disk image container ($TOTAL_SECTORS sectors / ~15.5 GB)..."
rm -f "$RAW_IMG"
truncate -s $(( TOTAL_SECTORS * 512 )) "$RAW_IMG"

echo "[*] Writing ChromeOS Depthcharge GPT partition table with cgpt..."
"$CGPT" create "$RAW_IMG"
"$CGPT" add -i 1 -b "$P1_START" -s "$P1_SIZE" -t data -l misc "$RAW_IMG"
"$CGPT" add -i 2 -b "$P2_START" -s "$P2_SIZE" -t kernel -l KERN-A -S 1 -T 15 -P 15 "$RAW_IMG"
"$CGPT" boot -p -i 2 "$RAW_IMG"
"$CGPT" add -i 3 -b "$P3_START" -s "$P3_SIZE" -t data -l metadata "$RAW_IMG"
"$CGPT" add -i 4 -b "$P4_START" -s "$P4_SIZE" -t data -l super "$RAW_IMG"
"$CGPT" add -i 5 -b "$P5_START" -s "$P5_SIZE" -t data -l userdata "$RAW_IMG"

echo "[*] Creating formatted metadata ext4 filesystem..."
METADATA_IMG="$WORK_DIR/metadata.img"
mke2fs -q -F -t ext4 -b 4096 -L metadata "$METADATA_IMG" $(( P3_SIZE * 512 / 1024 ))k

echo "[*] Creating formatted userdata f2fs filesystem (no casefold)..."
USERDATA_IMG="$WORK_DIR/userdata.img"
truncate -s $(( P5_SIZE * 512 )) "$USERDATA_IMG"
"$HOST_OUT/bin/make_f2fs" -f -q -g android -O encrypt,extra_attr,project_quota,quota,compression -l data "$USERDATA_IMG"

echo "[*] Burning KERN-A (vmlinuz.kpart) into partition 2..."
dd if="$VMLINUZ_KPART" of="$RAW_IMG" bs=1M seek=$(( P2_START / 2048 )) conv=notrunc status=none

echo "[*] Burning metadata into partition 3..."
dd if="$METADATA_IMG" of="$RAW_IMG" bs=1M seek=$(( P3_START / 2048 )) conv=notrunc status=none

echo "[*] Burning super.raw.img into partition 4..."
dd if="$SUPER_RAW" of="$RAW_IMG" bs=1M seek=$(( P4_START / 2048 )) conv=notrunc status=progress

echo "[*] Burning userdata into partition 5..."
dd if="$USERDATA_IMG" of="$RAW_IMG" bs=4M seek=$(( P5_START / 8192 )) conv=notrunc status=progress

echo "[*] Partition table verification:"
"$CGPT" show "$RAW_IMG"

if [ "$COMPRESS_XZ" = true ]; then
    echo "============================================================"
    echo "[*] Compressing disk image with multi-threaded XZ..."
    echo "============================================================"
    xz -T0 -8 -f "$RAW_IMG"
    FINAL_IMG="$PRODUCT_OUT/${RELEASE_NAME}.img.xz"
    if [ "$OUTPUT_TO_DESKTOP" = true ]; then
        mv "$FINAL_IMG" "$DEST_DIR/${RELEASE_NAME}.img.xz"
        FINAL_IMG="$DEST_DIR/${RELEASE_NAME}.img.xz"
    fi
else
    FINAL_IMG="$RAW_IMG"
    if [ "$OUTPUT_TO_DESKTOP" = true ]; then
        mv "$RAW_IMG" "$DEST_DIR/${RELEASE_NAME}.img"
        FINAL_IMG="$DEST_DIR/${RELEASE_NAME}.img"
    fi
fi

echo ""
echo "============================================================"
echo " [SUCCESS] Image built successfully!"
echo " Image: $FINAL_IMG"
echo " Size:  $(du -h "$FINAL_IMG" | awk '{print $1}')"
echo " "
echo " How to use:"
echo " 1. Flash to USB stick or SD card with balenaEtcher, Rufus, or dd."
echo " 2. Boot on Chromebook in Developer Mode with Ctrl + U."
echo "============================================================"
