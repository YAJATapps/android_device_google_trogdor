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

# Curated kernel modules list for Google Trogdor (SC7180)
# Boot-critical drivers (DRM MSM display, GPU, eMMC, clocks, regulators, PMIC, Binder)
# are built directly into the kernel (=y). Only loadable accessory modules are listed here.

VENDOR_DLKM_KERNEL_MODULES_LIST := \
    ath.ko \
    ath10k_core.ko \
    ath10k_pci.ko \
    ath10k_snoc.ko \
    btbcm.ko \
    btintel.ko \
    btqca.ko \
    btqcomsmd.ko \
    btrtl.ko \
    btusb.ko \
    cros-ec-sensors-core.ko \
    cros_ec_baro.ko \
    cros_ec_chardev.ko \
    cros_ec_light_prox.ko \
    cros_ec_sensors.ko \
    fastrpc.ko \
    gpio-wcd934x.ko \
    hci_uart.ko \
    i2c-qcom-cci.ko \
    leds-cros_ec.ko \
    leds-qcom-lpg.ko \
    phy-qcom-edp.ko \
    pinctrl-lpass-lpi.ko \
    pwrseq-qcom-wcn.ko \
    qcom-camss.ko \
    qcom-coincell.ko \
    qcom-pon.ko \
    qcom-rng.ko \
    qcom-spmi-adc-tm5.ko \
    qcom-spmi-adc5.ko \
    qcom-spmi-temp-alarm.ko \
    qcom_q6v5_adsp.ko \
    qcom_q6v5_pas.ko \
    qcom_stats.ko \
    qcom_wcnss_pil.ko \
    snd-soc-cros-ec-codec.ko \
    snd-soc-lpass-cdc-dma.ko \
    snd-soc-lpass-cpu.ko \
    snd-soc-lpass-hdmi.ko \
    snd-soc-lpass-macro-common.ko \
    snd-soc-lpass-platform.ko \
    snd-soc-lpass-rx-macro.ko \
    snd-soc-lpass-sc7180.ko \
    snd-soc-lpass-tx-macro.ko \
    snd-soc-lpass-va-macro.ko \
    snd-soc-lpass-wsa-macro.ko \
    snd-soc-max98357a.ko \
    snd-soc-qcom-common.ko \
    snd-soc-rt5682-i2c.ko \
    snd-soc-rt5682.ko \
    snd-soc-rt5682s.ko \
    snd-soc-sc7180.ko \
    snd-soc-simple-amplifier.ko \
    snd-soc-wsa881x.ko \
    atmel_mxt_ts.ko \
    cros_usbpd-charger.ko \
    cros_usbpd_logger.ko \
    edt-ft5x06.ko \
    elan_i2c.ko \
    elants_i2c.ko \
    goodix_ts.ko \
    hid-google-hammer.ko \
    hid-multitouch.ko \
    hid-vivaldi.ko \
    hid-vivaldi-common.ko \
    i2c-hid.ko \
    i2c-hid-of.ko \
    i2c-hid-of-goodix.ko
