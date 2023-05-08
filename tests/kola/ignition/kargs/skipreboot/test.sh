#!/bin/bash
set -xeuo pipefail
# kola: { "platforms": "qemu", "appendFirstbootKernelArgs": "foobar" }
# This test verifies that if a kernel argument that is set as "should_exist"
# in the Ignition config already exists on the kernel command line of the machine
# then we can skip the reboot when applying kernel arguments but we must still
# update the BLS configs to make it permanent. This is Scenario B from
# the documentation in 35coreos-ignition/coreos-kargs.sh.
#
# - platforms: qemu
#   - appendFirstbootKernelArgs is only supported on qemu.
# - appendFirstbootKernelArgs: foobar
#   - The kernel argument to apply transiently only on the first boot.

. $KOLA_EXT_DATA/commonlib.sh

kargchecks() {
    if ! grep foobar /proc/cmdline; then
        fatal "missing expected kernel arg in kernel cmdline"
    fi
    if ! grep foobar /boot/loader/entries/*.conf; then
        fatal "missing expected kernel arg in BLS config"
    fi
}

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      kargchecks
      # If this file exists then reboot was skipped. See
      # 35coreos-ignition/coreos-kargs.sh
      if [ ! -e /run/coreos-kargs-changed ]; then
          fatal "missing file that should exist if no reboot happened"
      fi
      # Now reboot the machine and verify the kernel argument persists
      /tmp/autopkgtest-reboot nextboot
      ;;
  nextboot)
      kargchecks
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac

ok "Ignition kargs skip reboot"
