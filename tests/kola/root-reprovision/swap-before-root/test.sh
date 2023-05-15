#!/bin/bash
## kola:
##   # This test's config manually references /dev/vda and is thus QEMU only
##   platforms: qemu
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   # We intentionally put the root filesystem on partition 5.  This is
##   # legal but usually not intended, so Butane warns about it.
##   allowConfigWarnings: true
##   # This test reprovisions the rootfs.
##   tags: reprovision

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
