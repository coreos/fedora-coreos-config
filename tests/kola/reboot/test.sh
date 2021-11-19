#!/bin/bash
set -xeuo pipefail
# kola: {"platforms": "qemu"}

# These are read-only not-necessarily-related checks that verify default system
# configuration both on first and subsequent boots.

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

# /var
varsrc=$(findmnt -nvr /var -o SOURCE)
rootsrc=$(findmnt -nvr / -o SOURCE)
[[ $(realpath "$varsrc") == $(realpath "$rootsrc") ]]
ok "/var is backed by rootfs"

# sanity-check that boot is mounted by UUID
if ! systemctl cat boot.mount | grep -q What=/dev/disk/by-uuid; then
  systemctl cat boot.mount
  fatal "boot mounted not by UUID"
fi
ok "boot mounted by UUID"

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      ok "first boot"
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      # check for expected default kargs
      grep root=UUID= /proc/cmdline
      ok "found root karg"

      grep boot=UUID= /proc/cmdline
      ok "found boot karg"

      ok "second boot"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
