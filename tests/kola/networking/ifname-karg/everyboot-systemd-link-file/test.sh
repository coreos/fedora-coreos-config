#!/bin/bash
## kola:
##   description: Verify persistent ifname= karg works via systemd-network-generator.
##   # appendFirstbootKernelArgs is only supported on QEMU
##   platforms: qemu
##   # Don't run the propagate code. With this test we want to
##   # validate that the systemd.link file gets created by
##   # systemd-network-generator.
##   appendFirstbootKernelArgs: "coreos.no_persist_ip"

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"
. $KOLA_EXT_DATA/ifname-karg-lib.sh

nicname='kolatest'

run_tests() {
    # Make sure nothing was persisted from the initramfs
    check_file_not_exists '/etc/udev/rules.d/80-ifname.rules'
    # Make sure systemd-network-generator ran (from the real root)
    check_file_exists "/run/systemd/network/*-${nicname}.link"
    # Make sure the NIC is in use and got the expected IP address
    check_ip "${nicname}"
}

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
    "")
        ok "first boot"
        run_tests
        /tmp/autopkgtest-reboot rebooted
      ;;

    rebooted)
        ok "second boot"
        run_tests
      ;;

  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
