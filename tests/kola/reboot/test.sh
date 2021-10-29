#!/bin/bash
set -xeuo pipefail
# kola: {"platforms": "qemu"}

# These are read-only not-necessarily-related checks that verify default system
# configuration both on first and subsequent boots.

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

# /var
varsrc=$(findmnt -nvr /var -o SOURCE)
rootsrc=$(findmnt -nvr / -o SOURCE)
[[ $(realpath "$varsrc") == $(realpath "$rootsrc") ]]
ok "/var is backed by rootfs"

# sanity-check that boot is mounted by UUID
if ! systemctl cat boot.mount | grep -q What=/dev/disk/by-uuid; then
  systemctl cat boot.mount
  fatal "boot mounted not by UUID"
fi
ok "boot mounted by UUID"

# check that we took ownership of the bootfs
[ -f /boot/.root_uuid ]

# check for the UUID dropins
[ -f /boot/grub2/bootuuid.cfg ]
mount -o ro /dev/disk/by-label/EFI-SYSTEM /boot/efi
[ -f /boot/efi/EFI/*/bootuuid.cfg ]
umount /boot/efi

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      ok "first boot"
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      # check for expected default kargs
      grep root=UUID=$(cat /boot/.root_uuid) /proc/cmdline
      ok "found root karg"

      bootsrc=$(findmnt -nvr /boot -o SOURCE)
      eval $(blkid -o export "${bootsrc}")
      grep boot=UUID=${UUID} /proc/cmdline
      ok "found boot karg"

      ok "second boot"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
