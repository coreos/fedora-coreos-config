#!/bin/bash
# kola: {"platforms": "qemu", "minMemory": 4096, "architectures": "!s390x"}
set -xeuo pipefail

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

srcdev=$(findmnt -nvr / -o SOURCE)
[[ ${srcdev} == /dev/mapper/myluksdev ]]

blktype=$(lsblk -o TYPE "${srcdev}" --noheadings)
[[ ${blktype} == crypt ]]

fstype=$(findmnt -nvr / -o FSTYPE)
[[ ${fstype} == xfs ]]
ok "source is XFS on LUKS device"

rootflags=$(findmnt /sysroot -no OPTIONS)
if ! grep prjquota <<< "${rootflags}"; then
    fatal "missing prjquota in root mount flags: ${rootflags}"
fi
ok "root mounted with prjquota"

# while we're here, sanity-check that boot is mounted by UUID
if ! systemctl cat boot.mount | grep -q What=/dev/disk/by-uuid; then
  systemctl cat boot.mount
  fatal "boot mounted not by UUID"
fi
ok "boot mounted by UUID"

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      # check that ignition-ostree-growfs ran
      if [ ! -e /run/ignition-ostree-growfs.stamp ]; then
          fatal "ignition-ostree-growfs did not run"
      fi

      # reboot once to sanity-check we can find root on second boot
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      grep root=UUID= /proc/cmdline
      grep rd.luks.name= /proc/cmdline
      ok "found root kargs"

      # while we're here, sanity-check that we have a boot=UUID karg too
      grep boot=UUID= /proc/cmdline
      ok "found boot karg"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
