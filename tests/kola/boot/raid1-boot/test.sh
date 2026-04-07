#!/bin/bash
## kola:
##   # additionalDisks is only supported on qemu.
##   platforms: qemu
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # Linear RAID is setup on these disks.
##   additionalDisks: ["16G"]
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   # bootupd does not support bootloader update on s390x
##   architectures: "! s390x"
##   # This test reprovisions the boot and rootfs.
##   tags: reprovision
##   description: Verify updating multiple EFIs using RAID 1 works.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

tmpdir=$(mktemp -d)
cd "${tmpdir}"

srcdev=$(findmnt -nvr /sysroot -o SOURCE)
[[ "${srcdev}" == "/dev/md126" ]]

blktype=$(lsblk -o TYPE "${srcdev}" --noheadings)
[[ "${blktype}" == "raid1" ]]

fstype=$(findmnt -nvr /sysroot -o FSTYPE)
[[ "${fstype}" == "xfs" ]]
ok "source is XFS on RAID1 device"

mount -o remount,rw /boot
rm -f -v /boot/bootupd-state.json

bootupctl adopt-and-update | tee out.txt
assert_file_has_content out.txt "Adopted and updated: BIOS: .*"
assert_file_has_content out.txt "Adopted and updated: EFI: .*"

bootupctl status | tee out.txt
assert_file_has_content_literal out.txt 'Component BIOS'
assert_file_has_content_literal out.txt 'Component EFI'
ok "bootupctl adopt-and-update supports multiple EFIs on RAID1"
