#! /vendor/bin/sh
# Set vendor.hw property to run device specific services
#
# grep the device name from /proc/device-tree/compatible

HW=`/vendor/bin/cat /proc/device-tree/compatible | /vendor/bin/grep homestar`
if [ -n "${HW}" ]; then
    setprop vendor.hw homestar
    setprop vendor.thermal.config thermal-trogdor.json
    exit 0
fi

HW=`/vendor/bin/cat /proc/device-tree/compatible | /vendor/bin/grep -E 'trogdor|wormdingler'`
if [ -n "${HW}" ]; then
    setprop vendor.hw trogdor
    setprop vendor.thermal.config thermal-trogdor.json
    exit 0
fi
