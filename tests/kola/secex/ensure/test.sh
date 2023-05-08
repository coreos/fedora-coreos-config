#!/bin/bash
## kola:
##   architectures: s390x
##   platforms: qemu
##   requiredTag: secex
##   timeoutMin: 3
##   description: Verify the s390x Secure Execution QEMU image works. It also
##     implicitly tests Ignition config decryption. 

# We don't run it by default because it requires running with `--qemu-secex`.

set -xeuo pipefail

check_luks() {
    local mnt dev type
    mnt=${1}
    dev=$(findmnt -nvr ${mnt} -o SOURCE)
    type=$(lsblk -o TYPE "${dev}" --noheadings)
    [[ ${type} == crypt ]]
}

# 1 means system runs with Secure Execution
grep -q 1 /sys/firmware/uv/prot_virt_guest

# Check firstboot kargs have dm-verity hashes
grep -q rootfs.roothash /proc/cmdline
grep -q bootfs.roothash /proc/cmdline

# Check we have SE partition with sdboot image
mount /dev/disk/by-label/se /sysroot/se
[[ -f /sysroot/se/sdboot ]]

check_luks /
check_luks /boot
