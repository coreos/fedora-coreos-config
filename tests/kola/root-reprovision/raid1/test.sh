#!/bin/bash
# kola: { "platforms": "qemu", "minMemory": 4096, "additionalDisks": ["5G", "5G"], "timeoutMin": 15 }
#
# - platforms: qemu
#   - This test should pass everywhere if it passes anywhere.
#   - additionalDisks is only supported on qemu.
# - minMemory: 4096
#   - Root reprovisioning requires at least 4GiB of memory.
# - additionalDisks: ["5G", "5G"]
#   - A RAID1 is setup on these disks.
# - timeoutMin: 15
#   - This test includes a lot of disk I/O and needs a higher
#     timeout value than the default.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

srcdev=$(findmnt -nvr / -o SOURCE)
[[ ${srcdev} == $(realpath /dev/md/foobar) ]]

blktype=$(lsblk -o TYPE "${srcdev}" --noheadings)
[[ ${blktype} == raid1 ]]

fstype=$(findmnt -nvr / -o FSTYPE)
[[ ${fstype} == xfs ]]
ok "source is XFS on RAID1 device"

rootflags=$(findmnt /sysroot -no OPTIONS)
if ! grep prjquota <<< "${rootflags}"; then
    fatal "missing prjquota in root mount flags: ${rootflags}"
fi
ok "root mounted with prjquota"

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      # check that ignition-ostree-growfs didn't run
      if [ -e /run/ignition-ostree-growfs.stamp ]; then
          fatal "ignition-ostree-growfs ran"
      fi

      # reboot once to sanity-check we can find root on second boot
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      grep root=UUID= /proc/cmdline
      grep rd.md.uuid= /proc/cmdline
      ok "found root kargs"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
