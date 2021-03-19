#!/bin/bash
# kola: {"platforms": "qemu", "minMemory": 4096}
set -xeuo pipefail

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

fstype=$(findmnt -nvr / -o FSTYPE)
[[ $fstype == ext4 ]]
ok "source is ext4"

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
