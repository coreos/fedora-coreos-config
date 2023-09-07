#!/bin/bash
## kola:
##   architectures: s390x
##   platforms: qemu
##   requiredTag: secex
##   timeoutMin: 5
##   description: Verify the qemu-secex image reboots with SE enabled. It also
##     implicitly tests Ignition config decryption.

# We don't run it by default because it requires running with
# `--qemu-secex --qemu-secex-hostkey HKD-<serial>.crt`.

set -xeuo pipefail

grep -q 1 /sys/firmware/uv/prot_virt_guest

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
"")
    rpm-ostree kargs --append secex_test
    /tmp/autopkgtest-reboot rebooted
    ;;
rebooted)
    grep -q rd.luks.name=$(cryptsetup luksUUID /dev/disk/by-label/crypt_rootfs)=root /proc/cmdline
    grep -q secex_test /proc/cmdline
    ;;
*)
    echo "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";
    exit 1
    ;;
esac
