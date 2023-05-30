#!/bin/bash
## kola:
##   # additionalDisks is only supported on qemu.
##   platforms: qemu
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # Linear RAID is setup on these disks.
##   additionalDisks: ["5G", "5G"]
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   # This test reprovisions the rootfs.
##   tags: reprovision
##   description: Verify the root reprovision with linear RAID works.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

srcdev=$(findmnt -nvr / -o SOURCE)
[[ ${srcdev} == $(realpath /dev/md/foobar) ]]

blktype=$(lsblk -o TYPE "${srcdev}" --noheadings)
[[ ${blktype} == linear ]]

fstype=$(findmnt -nvr / -o FSTYPE)
[[ ${fstype} == xfs ]]
ok "source is XFS on linear device"

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

      # check that autosave-xfs didn't run
      if [ -e /run/ignition-ostree-autosaved-xfs.stamp ]; then
          fatal "unexpected autosaved XFS"
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
