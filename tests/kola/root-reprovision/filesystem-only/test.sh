#!/bin/bash
# kola: { "platforms": "qemu", "minMemory": 4096, "timeoutMin": 15 }
#
# - platforms: qemu
#   - This test should pass everywhere if it passes anywhere.
# - minMemory: 4096
#   - Root reprovisioning requires at least 4GiB of memory.
# - timeoutMin: 15
#   - This test includes a lot of disk I/O and needs a higher
#     timeout value than the default.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

fstype=$(findmnt -nvr / -o FSTYPE)
[[ $fstype == ext4 ]]
ok "source is ext4"

rootflags=$(findmnt /sysroot -no OPTIONS)
if ! grep debug <<< "${rootflags}"; then
    fatal "missing debug in root mount flags: ${rootflags}"
fi
ok "root mounted with debug"

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      # check that the partition was grown
      if [ ! -e /run/ignition-ostree-growfs.stamp ]; then
          fatal "ignition-ostree-growfs did not run"
      fi

      # reboot once to sanity-check we can find root on second boot
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      grep root=UUID= /proc/cmdline
      ok "found root karg"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
