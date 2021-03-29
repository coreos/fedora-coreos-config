#!/bin/bash
# kola: {"platforms": "qemu", "minMemory": 4096}
set -xeuo pipefail

fstype=$(findmnt -nvr / -o FSTYPE)
[[ $fstype == ext4 ]]

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      # check that the partition was grown
      if [ ! -e /run/ignition-ostree-growfs.stamp ]; then
          echo "ignition-ostree-growfs did not run"
          exit 1
      fi

      # reboot once to sanity-check we can find root on second boot
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      grep root=UUID= /proc/cmdline
      ;;
  *) echo "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}"; exit 1;;
esac
