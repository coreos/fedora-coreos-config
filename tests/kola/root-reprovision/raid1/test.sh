#!/bin/bash
# kola: {"platforms": "qemu", "minMemory": 4096, "additionalDisks": ["5G", "5G"]}
set -xeuo pipefail

srcdev=$(findmnt -nvr / -o SOURCE)
[[ ${srcdev} == $(realpath /dev/md/foobar) ]]

blktype=$(lsblk -o TYPE "${srcdev}" --noheadings)
[[ ${blktype} == raid1 ]]

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
      grep rd.md.uuid= /proc/cmdline
      ;;
  *) echo "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}"; exit 1;;
esac
