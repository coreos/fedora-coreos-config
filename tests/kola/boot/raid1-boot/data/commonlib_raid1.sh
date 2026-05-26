# shellcheck shell=bash
# Common checks for raid1-boot tests across different architectures.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

check_basic() {
    src_root=$(findmnt -nvr /sysroot -o SOURCE)
    name_root=$(mdadm --detail "$src_root" | grep "Name" | sed 's/.*: *//')
    [[ "${name_root}" == "md-root" ]] || fatal "expected /sysroot to be on md-root, got: ${name_root}"

    src_boot=$(findmnt -nvr /boot -o SOURCE)
    name_boot=$(mdadm --detail "$src_boot" | grep "Name" | sed 's/.*: *//')
    [[ "${name_boot}" == "md-boot" ]] || fatal "expected /boot to be on md-boot, got: ${name_boot}"

    blktype=$(lsblk -o TYPE "${src_root}" --noheadings)
    [[ "${blktype}" == "raid1" ]] || fatal "expected block type to be RAID1, got: ${blktype}"

    fstype=$(findmnt -nvr /sysroot -o FSTYPE)
    [[ "${fstype}" == "xfs" ]] || fatal "expected filesystem type to be XFS, got: ${fstype}"
}

check_bootupctl_components() {
    local components=()
    local output_file="out.txt"

    # Define components based on the passed architecture
    case "$(arch)" in
        x86_64) components=("BIOS" "EFI") ;;
        aarch64) components=("EFI") ;;
        *) fatal "Unhandled architecture: $(arch)" ;;
    esac

    # 1. Test adopt-and-update (on first boot)
    if [[ ${AUTOPKGTEST_REBOOT_MARK:-} != "verify-boot" ]]; then
        mount -o remount,rw /boot
        rm -f -v /boot/bootupd-state.json

        bootupctl adopt-and-update | tee "${output_file}"
        for comp in "${components[@]}"; do
            assert_file_has_content "${output_file}" "Adopted and updated: ${comp}: .*"
        done
    fi

    # 2. Test status
    bootupctl status | tee "${output_file}"
    for comp in "${components[@]}"; do
        assert_file_has_content_literal "${output_file}" "Component ${comp}"
    done
}

check_raid1_boot() {
    tmpdir=$(mktemp -d)
    cd "${tmpdir}"

    check_basic
    check_bootupctl_components

    case "${AUTOPKGTEST_REBOOT_MARK:-}" in
        "") /tmp/autopkgtest-reboot verify-boot ;;
        verify-boot) ok "Updated RAID1 boot" ;;
        *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}" ;;
    esac
}
