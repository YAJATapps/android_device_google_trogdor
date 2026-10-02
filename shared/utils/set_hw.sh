#! /vendor/bin/sh
# Set vendor.hw property to run device specific services
#
# grep the device name from /proc/device-tree/compatible

HW=`/vendor/bin/cat /proc/device-tree/compatible | /vendor/bin/grep trogdor`
if [ -n "${HW}" ]; then
    setprop vendor.hw trogdor
    setprop vendor.thermal.config thermal-trogdor.json
    exit 0
fi

HW=`/vendor/bin/cat /proc/device-tree/compatible | /vendor/bin/grep rb5`
if [ -n "${HW}" ]; then
    setprop vendor.hw rb5
    exit 0
fi

HW=`/vendor/bin/cat /proc/device-tree/compatible | /vendor/bin/grep sm8550-hdk`
if [ -n "${HW}" ]; then
    setprop vendor.hw sm8550hdk
    exit 0
fi

HW=`/vendor/bin/cat /proc/device-tree/compatible | /vendor/bin/grep sm8550-qrd`
if [ -n "${HW}" ]; then
    setprop vendor.hw sm8550qrd
    exit 0
fi

HW=`/vendor/bin/cat /proc/device-tree/compatible | /vendor/bin/grep sm8650-qrd`
if [ -n "${HW}" ]; then
    setprop vendor.hw sm8650qrd
    exit 0
fi
