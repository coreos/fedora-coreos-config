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

check_bootupctl_components() {
    local arch_type="$1"
    local components=()
    local output_file="out.txt"

    # Define components based on the passed architecture
    case "${arch_type}" in
        x86_64)  components=("BIOS" "EFI") ;;
        aarch64) components=("EFI") ;;
        ppc64le) components=("BIOS") ;;
        *)
            echo "Skipped checking for arch: ${arch_type}"
            return 0
            ;;
    esac

    # 1. Test adopt-and-update
    bootupctl adopt-and-update | tee "${output_file}"
    for comp in "${components[@]}"; do
        assert_file_has_content "${output_file}" "Adopted and updated: ${comp}: .*"
    done

    # 2. Test status
    bootupctl status | tee "${output_file}"
    for comp in "${components[@]}"; do
        assert_file_has_content_literal "${output_file}" "Component ${comp}"
    done
}

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

check_bootupctl_components "$(arch)"

ok "bootupctl adopt-and-update supports RAID1 boot"
