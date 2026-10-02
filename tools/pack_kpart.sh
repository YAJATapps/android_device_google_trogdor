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

# 1. Compress Kernel
echo "--> Compressing kernel Image with LZ4..."
"$LZ4" -9 -f "$PRODUCT_OUT/kernel" "$WORK_DIR/Image.lz4"

# 2. Copy DTBs and Ramdisk
cp "$DTS_DIR"/sc7180-trogdor-wormdingler*.dtb "$WORK_DIR/"
cp "$PRODUCT_OUT/ramdisk.img" "$WORK_DIR/ramdisk.img"

# 3. Create cmdline (support both internal eMMC and external USB booting)
echo "earlycon firmware_class.path=/vendor/firmware,/vendor/firmware/qcom init=/init printk.devkmsg=on deferred_probe_timeout=30 clk_ignore_unused pd_ignore_unused qcom_geni_serial.con_enabled=1 console=tty0 console=ttyMSM0,115200n8 vt.global_cursor_default=0 androidboot.boot_devices=soc@0/7c4000.mmc,soc@0/a6f8800.usb,any androidboot.hardware=trogdor androidboot.verifiedbootstate=orange androidboot.slot_suffix=_a androidboot.selinux=permissive" > "$WORK_DIR/cmdline"

# 4. Generate ITS description
cat << 'EOF' > "$WORK_DIR/kernel.its"
/dts-v1/;

/ {
    description = "LineageOS kernel image for Google Trogdor (Wormdingler)";
    #address-cells = <1>;

    images {
        kernel {
            description = "ARM64 Linux Kernel";
            data = /incbin/("Image.lz4");
            type = "kernel_noload";
            arch = "arm64";
            os = "linux";
            compression = "lz4";
            load = <0>;
            entry = <0>;
            hash {
                algo = "sha1";
            };
        };
        ramdisk {
            description = "Android First-Stage Ramdisk";
            data = /incbin/("ramdisk.img");
            type = "ramdisk";
            arch = "arm64";
            os = "linux";
            compression = "gzip";
            load = <0>;
            hash {
                algo = "sha1";
            };
        };
        fdt-1 {
            description = "sc7180-trogdor-wormdingler-rev1-boe.dtb";
            data = /incbin/("sc7180-trogdor-wormdingler-rev1-boe.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash {
                algo = "sha1";
            };
        };
        fdt-2 {
            description = "sc7180-trogdor-wormdingler-rev1-boe-rt5682s.dtb";
            data = /incbin/("sc7180-trogdor-wormdingler-rev1-boe-rt5682s.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash {
                algo = "sha1";
            };
        };
        fdt-3 {
            description = "sc7180-trogdor-wormdingler-rev1-inx.dtb";
            data = /incbin/("sc7180-trogdor-wormdingler-rev1-inx.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash {
                algo = "sha1";
            };
        };
        fdt-4 {
            description = "sc7180-trogdor-wormdingler-rev1-inx-rt5682s.dtb";
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
            description = "Lenovo Chromebook Duet 3 (BOE panel)";
            kernel = "kernel";
            ramdisk = "ramdisk";
            fdt = "fdt-1";
        };
        conf-2 {
            description = "Lenovo Chromebook Duet 3 (BOE panel + RT5682S)";
            kernel = "kernel";
            ramdisk = "ramdisk";
            fdt = "fdt-2";
        };
        conf-3 {
            description = "Lenovo Chromebook Duet 3 (Innolux panel)";
            kernel = "kernel";
            ramdisk = "ramdisk";
            fdt = "fdt-3";
        };
        conf-4 {
            description = "Lenovo Chromebook Duet 3 (Innolux panel + RT5682S)";
            kernel = "kernel";
            ramdisk = "ramdisk";
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
