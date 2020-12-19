#!/bin/bash
# kola: {"platforms": "qemu", "minMemory": 4096, "architectures": "!s390x"}
set -xeuo pipefail

srcdev=$(findmnt -nvr / -o SOURCE)
[[ ${srcdev} == /dev/mapper/myluksdev ]]

blktype=$(lsblk -o TYPE "${srcdev}" --noheadings)
[[ ${blktype} == crypt ]]

fstype=$(findmnt -nvr / -o FSTYPE)
[[ ${fstype} == xfs ]]

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      # check that growpart didn't run
      if [ -e /run/coreos-growpart.stamp ]; then
          echo "coreos-growpart ran"
          exit 1
      fi

      # reboot once to sanity-check we can find root on second boot
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      grep root=UUID= /proc/cmdline
      grep rd.luks.name= /proc/cmdline
      ;;
  *) echo "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}"; exit 1;;
esac
