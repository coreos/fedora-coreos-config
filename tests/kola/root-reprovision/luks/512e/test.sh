#!/bin/bash
## kola:
##   # This test reprovisions the rootfs.
##   tags: "reprovision"
##   # This uses additionalDisks, which is QEMU only
##   platforms: qemu
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # A TPM backend device is not available on s390x to suport TPM.
##   architectures: "! s390x"
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   description: Verify that LUKS on a 512e disks works.
##   primaryDisk: ":512e"

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# sanity-check that it's a 512e disk
phy_sec=$(blockdev --getpbsz /dev/disk/by-id/virtio-primary-disk)
log_sec=$(blockdev --getss /dev/disk/by-id/virtio-primary-disk)
if [ "${phy_sec}" != 4096 ] || [ "${log_sec}" != 512 ]; then
    fatal "root device isn't 512e"
fi

# sanity-check that LUKS chose a 4096 sector size
luks_sec=$(blockdev --getss /dev/mapper/myluksdev)
if [ "${luks_sec}" != 4096 ]; then
    fatal "root LUKS device isn't 4k"
fi

# run the rest of the tests
. $KOLA_EXT_DATA/luks-test.sh
