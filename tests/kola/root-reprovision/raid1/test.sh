#!/bin/bash
# kola: {"platforms": "qemu", "minMemory": 4096, "additionalDisks": ["5G", "5G"]}
set -xeuo pipefail

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

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
