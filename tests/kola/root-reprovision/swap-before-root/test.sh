#!/bin/bash
# This test only runs on FCOS due to a problem enabling a swap partition on
# RHCOS.  See: https://github.com/openshift/os/issues/665
# kola: {"distros": "fcos", "platforms": "qemu", "minMemory": 4096}
set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

swapstatus=$(systemctl is-active dev-disk-by\\x2dpartlabel-swap.swap)
[[ ${swapstatus} == active ]]
ok "swap is active"

fstype=$(findmnt -nvr / -o FSTYPE)
[[ ${fstype} == xfs ]]
ok "source is xfs"

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      # reboot once to sanity-check we can find root on second boot
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      grep root=UUID= /proc/cmdline
      ok "found root karg"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
