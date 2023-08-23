#!/bin/bash
## kola:
##   platforms: qemu
##   description: Verify default system configuration are both on first and
##     subsequent boots.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

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

# s390x does not have grub, skip this part

if [ "$(arch)" == "ppc64le" ] || [ "$(arch)" == "s390x" ]; then
  echo "skipping EFI verification on arch $(arch)"
else
  # check for the UUID dropins
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

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      ok "first boot"
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      # check for expected default kargs
      grep root=UUID="$(cat /boot/.root_uuid)" /proc/cmdline
      ok "found root karg"

      bootsrc=$(findmnt -nvr /boot -o SOURCE)
      eval $(blkid -p -o export "${bootsrc}")
      grep boot=UUID="${UUID}" /proc/cmdline
      ok "found boot karg"

      ok "second boot"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
