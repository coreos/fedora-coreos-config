#!/bin/bash
## kola:
##   # This uses appendKernelArgs and multipath, which is QEMU only
##   platforms: qemu
##   description: Verify multipath resiliency against multiple boot labels and no root karg.
##   primaryDisk: ":mpath"
##   # notice we don't add a `root=/dev/disk/by-label/dm-mpath-root` karg here
##   appendKernelArgs: "rd.multipath=default"
##   additionalDisks: ["1G:serial=fakeboot", "1G:mpath,wwn=11"]

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# we may race with the /boot mount
if ! is_service_active boot.mount; then
  fatal "boot.mount failed to activate"
fi

# did we mount the right bootfs?
test -d /boot/ostree

# is it on multipath?
src=$(findmnt -nvr -o SOURCE /boot)
udevadm info "$src" | grep DM_MPATH

# was it mounted using dm-mpath-... ?
systemctl cat boot.mount | tee /tmp/out.txt
grep What=/dev/disk/by-uuid/dm-mpath- /tmp/out.txt

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      ok "first boot"
      mkfs.ext4 -L boot /dev/disk/by-id/virtio-fakeboot
      mkfs.ext4 -L boot /dev/disk/by-id/wwn-0xx000000000000000b
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      cat /proc/cmdline
      grep boot=UUID= /proc/cmdline
      grep root=UUID= /proc/cmdline
      ok "reboot"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
