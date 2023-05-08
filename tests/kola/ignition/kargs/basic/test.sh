#!/bin/bash
# TODO: Doc

set -xeuo pipefail
# This test runs on all platforms and verifies Ignition kernel argument setting.

. $KOLA_EXT_DATA/commonlib.sh

kargchecks() {
    if ! grep foobar /proc/cmdline; then
        fatal "missing foobar in kernel cmdline"
    fi
    if grep mitigations /proc/cmdline; then
        fatal "found mitigations in kernel cmdline"
    fi
}

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      kargchecks
      # Now reboot the machine and verify the kernel argument persists
      /tmp/autopkgtest-reboot nextboot
      ;;
  nextboot)
      kargchecks
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac

ok "Ignition kargs"
