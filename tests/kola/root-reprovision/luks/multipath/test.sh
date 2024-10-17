#!/bin/bash
## kola:
##   # This test reprovisions the rootfs.
##   tags: "reprovision"
##   # This uses appendKernelArgs and multipath, which is QEMU only
##   platforms: qemu
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # A TPM backend device is not available on s390x to suport TPM.
##   architectures: "! s390x"
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   description: Verify that LUKS on a mpath disks works.
##   primaryDisk: ":mpath"
##   appendKernelArgs: "rd.multipath=default"

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# Check if the child device is part of the parent device
srcdev=$(findmnt -nvr /sysroot -o SOURCE)
parent_device="/dev/mapper/mpatha"

if ! lsblk -pno NAME "$parent_device" | grep -qw "$srcdev"; then
    fatal "$srcdev is NOT a child of $parent_device."
fi
ok "$srcdev device is part of the parent $parent_device device"

# run the rest of the tests
. $KOLA_EXT_DATA/luks-test.sh
