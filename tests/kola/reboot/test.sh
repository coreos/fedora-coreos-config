#!/bin/bash
## kola:
##   platforms: qemu
##   description: Verify default system configuration are both on first and
##     subsequent boots.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

first_boot_sanity_check() {
    # /var
    varsrc=$(findmnt -nvr /var -o SOURCE)
    rootsrc=$(findmnt -nvr /sysroot -o SOURCE)
    [[ $(realpath "$varsrc") == $(realpath "$rootsrc") ]]
    ok "/var is backed by rootfs"

    # check that boot is mounted by UUID
    if ! systemctl cat boot.mount | grep -q What=/dev/disk/by-uuid; then
        systemctl cat boot.mount
        fatal "boot mounted not by UUID"
    fi
    ok "boot mounted by UUID"

    # check that we took ownership of the bootfs
    [ -f /boot/.root_uuid ]

    # check for the UUID dropins
    if [ "$(arch)" == "ppc64le" ] || [ "$(arch)" == "s390x" ]; then
        echo "skipping EFI verification on arch $(arch)"
    else
        [ -f /boot/grub2/bootuuid.cfg ]
        mount -o ro /dev/disk/by-label/EFI-SYSTEM /boot/efi
        found_bootuuid="false"
        for f in /boot/efi/EFI/*/bootuuid.cfg; do
            if [ -f "$f" ]; then
                found_bootuuid="true"
            fi
        done
        if [[ "${found_bootuuid}" == "false" ]]; then
            fatal "No /boot/efi/EFI/*/bootuuid.cfg found"
        fi
        umount /boot/efi
    fi
}

subsequent_boot_sanity_check() {
    # check for expected root=UUID= and boot=UUID= kargs that were set up on
    # first boot for use in subsequent boots.
    grep root=UUID="$(cat /boot/.root_uuid)" /proc/cmdline
    ok "found root karg"
    bootsrc=$(findmnt -nvr /boot -o SOURCE)
    eval $(blkid -p -o export "${bootsrc}")
    grep boot=UUID="${UUID}" /proc/cmdline
    ok "found boot karg"
}

# Boot 10 times to find any issues with multiple boots
# and then verify expected settings on the last boot.
case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      first_boot_sanity_check
      ok "first boot"
      /tmp/autopkgtest-reboot 2
      ;;
  [2-9])
      ok "boot ${AUTOPKGTEST_REBOOT_MARK}"
      /tmp/autopkgtest-reboot "$((${AUTOPKGTEST_REBOOT_MARK} + 1))"
      ;;
  10)
      subsequent_boot_sanity_check
      ok "boot 10"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
