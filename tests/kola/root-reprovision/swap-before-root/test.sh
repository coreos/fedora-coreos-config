#!/bin/bash
# kola: { "distros": "fcos", "platforms": "qemu", "minMemory": 4096, "timeoutMin": 15, "allowConfigWarnings": true }
#
# - distros: fcos
#   - This test only runs on FCOS due to a problem enabling a swap partition on
#     RHCOS. See: https://github.com/openshift/os/issues/665
# - platforms: qemu
#   - This test should pass everywhere if it passes anywhere.
# - minMemory: 4096
#   - Root reprovisioning requires at least 4GiB of memory.
# - timeoutMin: 15
#   - This test includes a lot of disk I/O and needs a higher
#     timeout value than the default.
# - allowConfigWarnings: true
#   - We intentionally put the root filesystem on partition 5.  This is
#     legal but usually not intended, so Butane warns about it.

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
