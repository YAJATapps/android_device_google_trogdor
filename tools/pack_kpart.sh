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

# 1. Compress raw Kernel Image with LZMA (required by Depthcharge arm64 trampoline)
echo "--> Compressing kernel Image with LZMA..."
lzma -9 -c "$PRODUCT_OUT/kernel" > "$WORK_DIR/Image.lzma"

# 2. Copy DTBs and Ramdisk
cp "$DTS_DIR"/sc7180-trogdor-wormdingler*.dtb "$WORK_DIR/"
cp "$PRODUCT_OUT/ramdisk.img" "$WORK_DIR/ramdisk.img"

# 3. Create cmdline (support both internal eMMC and external USB booting)
echo "earlycon firmware_class.path=/vendor/firmware,/vendor/firmware/qcom init=/init printk.devkmsg=on deferred_probe_timeout=30 clk_ignore_unused pd_ignore_unused qcom_geni_serial.con_enabled=1 console=tty0 console=ttyMSM0,115200n8 vt.global_cursor_default=0 androidboot.boot_devices=soc@0/7c4000.mmc,soc@0/a6f8800.usb,any androidboot.hardware=trogdor androidboot.verifiedbootstate=orange androidboot.slot_suffix=_a androidboot.selinux=permissive" > "$WORK_DIR/cmdline"

# 4. Generate ITS description (matching working postmarketOS Depthcharge FIT structure)
cat << 'EOF' > "$WORK_DIR/kernel.its"
/dts-v1/;

/ {
    description = "LineageOS kernel image for Google Trogdor (Wormdingler)";
    #address-cells = <1>;

    images {
        kernel-1 {
            description = "ARM64 Linux Kernel";
            data = /incbin/("Image.lzma");
            type = "kernel_noload";
            arch = "arm64";
            os = "linux";
            compression = "lzma";
            load = <0x0>;
            entry = <0x0>;
            hash {
                algo = "sha1";
            };
        };
        ramdisk-1 {
            description = "Android First-Stage Ramdisk";
            data = /incbin/("ramdisk.img");
            type = "ramdisk";
            arch = "arm64";
            os = "linux";
            hash {
                algo = "sha1";
            };
        };
        fdt-1 {
            description = "sc7180-trogdor-wormdingler-rev1-boe";
            data = /incbin/("sc7180-trogdor-wormdingler-rev1-boe.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash {
                algo = "sha1";
            };
        };
        fdt-2 {
            description = "sc7180-trogdor-wormdingler-rev1-boe-rt5682s";
            data = /incbin/("sc7180-trogdor-wormdingler-rev1-boe-rt5682s.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash {
                algo = "sha1";
            };
        };
        fdt-3 {
            description = "sc7180-trogdor-wormdingler-rev1-inx";
            data = /incbin/("sc7180-trogdor-wormdingler-rev1-inx.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash {
                algo = "sha1";
            };
        };
        fdt-4 {
            description = "sc7180-trogdor-wormdingler-rev1-inx-rt5682s";
            data = /incbin/("sc7180-trogdor-wormdingler-rev1-inx-rt5682s.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash {
                algo = "sha1";
            };
        };
    };

    configurations {
        default = "conf-1";
        conf-1 {
            description = "sc7180-trogdor-wormdingler-rev1-boe";
            kernel = "kernel-1";
            loadables = "kernel-1";
            ramdisk = "ramdisk-1";
            fdt = "fdt-1";
        };
        conf-2 {
            description = "sc7180-trogdor-wormdingler-rev1-boe-rt5682s";
            kernel = "kernel-1";
            loadables = "kernel-1";
            ramdisk = "ramdisk-1";
            fdt = "fdt-2";
        };
        conf-3 {
            description = "sc7180-trogdor-wormdingler-rev1-inx";
            kernel = "kernel-1";
            loadables = "kernel-1";
            ramdisk = "ramdisk-1";
            fdt = "fdt-3";
        };
        conf-4 {
            description = "sc7180-trogdor-wormdingler-rev1-inx-rt5682s";
            kernel = "kernel-1";
            loadables = "kernel-1";
            ramdisk = "ramdisk-1";
            fdt = "fdt-4";
        };
    };
};
EOF

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
    --arch arm

# 8. Verify
echo "--> Verifying packed image..."
"$FUTILITY" vbutil_kernel --verify "$OUT_KPART"

echo "==> Successfully created $OUT_KPART ($(ls -lh "$OUT_KPART" | awk '{print $5}'))"
