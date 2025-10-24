#!/bin/bash
## kola:
##   # This uses appendKernelArgs and multipath, which is QEMU only
##   platforms: qemu
##   description: Verify if multipath works with a custom partitioning
##   appendKernelArgs: "rd.multipath=default"
##   primaryDisk: "15G:mpath"

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if ! cat /proc/cmdline | grep -q rd.multipath=default; then
    fatal "kernel argument rd.multipath=default not defined"
fi

multipath -l -v 1

dm_mpath="/dev/mapper/$(multipath -l -v 1)"

if ! udevadm info --query=property "${dm_mpath}" | grep -q MPATH_DEVICE_READY=1; then
    fatal "device mapper ${dm_mpath} is not MPATH_DEVICE_READY"
fi

var_src=$(findmnt -nvr -o SOURCE /var)
if ! udevadm info --query=property "${var_src}" | grep "ID_FS_LABEL=var"; then
    fatal "/var partition do not have the label var"
fi

if ! udevadm info --query=property "${var_src}" | grep "DM_PART=5"; then
    fatal "/var partition number is not 5 as expected"
fi

