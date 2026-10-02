#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_TOP="${ANDROID_BUILD_TOP:-$(cd "$DEVICE_DIR/../../.." && pwd)}"
PRODUCT_OUT="${PRODUCT_OUT:-$BUILD_TOP/out/target/product/trogdor}"
KERNEL_OBJ="$PRODUCT_OUT/obj/KERNEL_OBJ"
DTS_DIR="$KERNEL_OBJ/arch/arm64/boot/dts/qcom"
OUT_KPART="$PRODUCT_OUT/vmlinuz.kpart"
WORK_DIR=$(mktemp -d -t kpart_pack_XXXXXX)

trap "rm -rf '$WORK_DIR'" EXIT

echo "==> Packaging ChromeOS Depthcharge KPART kernel for Lenovo Duet 3 (Wormdingler)..."

LZ4="$BUILD_TOP/prebuilts/kernel-build-tools/linux-x86/bin/lz4"
MKIMAGE="$BUILD_TOP/prebuilts/tools-lineage/linux-x86/bin/mkimage"
FUTILITY="$SCRIPT_DIR/bin/futility"
DTC="$BUILD_TOP/out/host/linux-x86/bin/dtc"
KEYBLOCK="$SCRIPT_DIR/devkeys/kernel.keyblock"
SIGNPRIVATE="$SCRIPT_DIR/devkeys/kernel_data_key.vbprivk"

# 1. Compress raw Kernel Image with LZ4 (required by Depthcharge boot64)
echo "--> Compressing kernel Image with LZ4..."
"$LZ4" -9 -f "$PRODUCT_OUT/kernel" "$WORK_DIR/Image.lz4"

# 2. Copy all Trogdor board DTBs (all 47 SKUs/variants) and Ramdisk
echo "--> Copying all Trogdor device trees and ramdisk..."
cp "$DTS_DIR"/sc7180-trogdor*.dtb "$WORK_DIR/"
cp "$PRODUCT_OUT/ramdisk.img" "$WORK_DIR/ramdisk.img"

# 3. Create cmdline (with tty0 last so messages show on screen, loglevel=7 for visible boot logs)
echo "earlycon firmware_class.path=/vendor/firmware,/vendor/firmware/qcom init=/init printk.devkmsg=on deferred_probe_timeout=30 clk_ignore_unused pd_ignore_unused qcom_geni_serial.con_enabled=1 console=ttyMSM0,115200n8 console=tty0 loglevel=7 vt.global_cursor_default=0 androidboot.boot_devices=soc@0/7c4000.mmc,soc@0/a6f8800.usb,any androidboot.hardware=trogdor androidboot.verifiedbootstate=orange androidboot.slot_suffix=_a androidboot.selinux=permissive" > "$WORK_DIR/cmdline"

# 4. Generate ITS description with CRC32 hashes matching Depthcharge & postmarketOS specifications
echo "--> Generating FIT ITS description for all $(ls "$WORK_DIR"/sc7180-trogdor*.dtb | wc -l) board variants..."
WORK_DIR="$WORK_DIR" python3 - << 'PYEOF'
import glob, os, struct

def get_root_compat(dtb_path):
    with open(dtb_path, 'rb') as f:
        data = f.read()
    magic, totalsize, off_struct, off_strings = struct.unpack_from('>IIII', data, 0)
    p = off_struct
    token = struct.unpack_from('>I', data, p)[0]
    p += 4
    while data[p] != 0:
        p += 1
    p = (p + 4) & ~3
    while p < len(data):
        token = struct.unpack_from('>I', data, p)[0]
        p += 4
        if token == 3: # FDT_PROP
            val_len, name_off = struct.unpack_from('>II', data, p)
            p += 8
            val_bytes = data[p : p + val_len]
            p = (p + val_len + 3) & ~3
            name_end = data.find(b'\0', off_strings + name_off)
            name = data[off_strings + name_off : name_end].decode('ascii')
            if name == 'compatible':
                return [s.decode('utf-8') for s in val_bytes.rstrip(b'\0').split(b'\0') if s]
        elif token in (1, 2):
            break
    return []

work_dir = os.environ.get("WORK_DIR", ".")
dtbs = sorted(glob.glob(f"{work_dir}/sc7180-trogdor*.dtb"))

lines = [
    '/dts-v1/;',
    '/',
    '{',
    '    description = "Kernel Image image with one or more FDT blobs";',
    '    #address-cells = <1>;',
    '    images {',
    '        kernel-1 {',
    '            description = "unavailable";',
    '            data = /incbin/("Image.lz4");',
    '            type = "kernel_noload";',
    '            arch = "arm64";',
    '            os = "linux";',
    '            compression = "lz4";',
    '            load = <0x0>;',
    '            entry = <0x0>;',
    '            hash {',
    '                algo = "crc32";',
    '            };',
    '        };',
    '        ramdisk-1 {',
    '            type = "ramdisk";',
    '            arch = "arm64";',
    '            os = "linux";',
    '            compression = "none";',
    '            data = /incbin/("ramdisk.img");',
    '            hash {',
    '                algo = "crc32";',
    '            };',
    '        };'
]

for i, d in enumerate(dtbs, 1):
    base = os.path.basename(d)[:-4]
    lines += [
        f'        fdt-{i} {{',
        f'            description = "{base}";',
        f'            data = /incbin/("{base}.dtb");',
        '            type = "flat_dt";',
        '            arch = "arm64";',
        '            compression = "none";',
        '            hash {',
        '                algo = "crc32";',
        '            };',
        '        };'
    ]

# Find Wormdingler BOE SKU 1024 as preferred default
default_conf = "conf-1"
for i, d in enumerate(dtbs, 1):
    base = os.path.basename(d)[:-4]
    if base == "sc7180-trogdor-wormdingler-rev1-boe":
        default_conf = f"conf-{i}"
        break

lines += [
    '    };',
    '    configurations {',
    f'        default = "{default_conf}";'
]

for i, d in enumerate(dtbs, 1):
    base = os.path.basename(d)[:-4]
    compats = get_root_compat(d)
    compat_formatted = ', '.join(f'"{c}"' for c in compats)
    lines += [
        f'        conf-{i} {{',
        f'            description = "{base}";',
        '            kernel = "kernel-1";',
        '            ramdisk = "ramdisk-1";',
        f'            fdt = "fdt-{i}";',
        f'            compatible = {compat_formatted};',
        '        };'
    ]

lines += [
    '    };',
    '};'
]

with open(f"{work_dir}/kernel.its", "w") as f:
    f.write('\n'.join(lines))
PYEOF

# 5. Build FIT Image
echo "--> Generating FIT Image (kernel.itb)..."
cd "$WORK_DIR"
PATH="$(dirname "$DTC"):$PATH" "$MKIMAGE" -D "-I dts -O dtb -p 2048" -f kernel.its kernel.itb >/dev/null

# 6. Dummy bootloader stub
echo "boot" > bootloader.bin

# 7. Sign and Pack with futility vbutil_kernel
echo "--> Signing with vboot devkeys into $OUT_KPART..."
"$FUTILITY" vbutil_kernel --pack "$OUT_KPART" \
    --keyblock "$KEYBLOCK" \
    --signprivate "$SIGNPRIVATE" \
    --version 1 \
    --config cmdline \
    --bootloader bootloader.bin \
    --vmlinuz kernel.itb \
    --arch aarch64

# 8. Verify
echo "--> Verifying packed image..."
"$FUTILITY" vbutil_kernel --verify "$OUT_KPART"

echo "==> Successfully created $OUT_KPART ($(ls -lh "$OUT_KPART" | awk '{print $5}'))"
