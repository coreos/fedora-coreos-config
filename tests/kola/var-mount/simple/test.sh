#!/bin/bash
## kola:
##   description: Verify that provision disk with guid works.
##   tags: platform-independent

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# /var

src=$(findmnt -nvr /var -o SOURCE)
[[ $(realpath "$src") == $(realpath /dev/disk/by-partuuid/63194b49-e4b7-43f9-9a8b-df0fd8279bb7) ]]

fstype=$(findmnt -nvr /var -o FSTYPE)
[[ $fstype == xfs ]]

# /var/log

src=$(findmnt -nvr /var/log -o SOURCE)
[[ $(realpath "$src") == $(realpath /dev/disk/by-partuuid/6385b84e-2c7b-4488-a870-667c565e01a8) ]]

fstype=$(findmnt -nvr /var/log -o FSTYPE)
[[ $fstype == ext4 ]]

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      ok "mounted on first boot"

      # reboot once to sanity-check we can mount on second boot
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      ok "mounted on reboot"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
