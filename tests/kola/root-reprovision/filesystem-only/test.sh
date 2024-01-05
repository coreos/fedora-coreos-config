#!/bin/bash
## kola:
##   # This test reprovisions the rootfs.
##   tags: "platform-independent reprovision"
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   description: Verify the root reprovisioning with specified file system works.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

fstype=$(findmnt -nvr /sysroot -o FSTYPE)
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
