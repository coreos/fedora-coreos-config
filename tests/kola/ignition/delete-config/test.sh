#!/bin/bash
## kola:
##   # Ideally we'd test on virtualbox and vmware, but we don't have tests
##   # there, so we mock specifically for ignition.platform.id=qemu
##   platforms: qemu

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
"")
    # Ignition boot

    if [ ! -e /run/ignition-rmcfg-ran ]; then
        fatal "mocked ignition-rmcfg did not run on first boot"
    fi

    if [ $(systemctl is-active ignition-delete-config ||:) != active ]; then
        fatal "ignition-delete-config didn't succeed on first boot"
    fi
    if [ $(systemctl is-active coreos-ignition-delete-config ||:) != active ]; then
        fatal "coreos-ignition-delete-config didn't succeed on first boot"
    fi
    ok "First boot OK"

    # Reset state and reboot
    rm /var/lib/coreos-ignition-delete-config.stamp
    /tmp/autopkgtest-reboot upgrade
    ;;

upgrade)
    # Simulated upgrade from Ignition < 2.14.0

    if [ ! -e /run/ignition-rmcfg-ran ]; then
        fatal "mocked ignition-rmcfg did not run on upgrade boot"
    fi

    if [ $(systemctl is-active ignition-delete-config ||:) != inactive ]; then
        fatal "ignition-delete-config ran on upgrade boot"
    fi
    if [ $(systemctl is-active coreos-ignition-delete-config ||:) != active ]; then
        fatal "coreos-ignition-delete-config didn't succeed on upgrade boot"
    fi
    ok "Upgrade boot OK"

    /tmp/autopkgtest-reboot steady-state
    ;;

steady-state)
    # Steady-state boot; nothing should run

    if [ -e /run/ignition-rmcfg-ran ]; then
        fatal "mocked ignition-rmcfg ran on steady-state boot"
    fi

    if [ $(systemctl is-active ignition-delete-config ||:) != inactive ]; then
        fatal "ignition-delete-config ran on steady-state boot"
    fi
    if [ $(systemctl is-active coreos-ignition-delete-config ||:) != inactive ]; then
        fatal "coreos-ignition-delete-config ran on steady-state boot"
    fi
    ok "Steady-state boot OK"

    # Reset state for masked unit and reboot
    rm /var/lib/coreos-ignition-delete-config.stamp
    systemctl mask ignition-delete-config.service
    /tmp/autopkgtest-reboot masked
    ;;

masked)
    # Simulated upgrade with masked ignition-delete-config.service

    if [ -e /run/ignition-rmcfg-ran ]; then
        fatal "mocked ignition-rmcfg ran on masked boot"
    fi

    if [ $(systemctl is-active ignition-delete-config ||:) != inactive ]; then
        fatal "ignition-delete-config ran on masked boot"
    fi
    if [ $(systemctl is-active coreos-ignition-delete-config ||:) != inactive ]; then
        fatal "coreos-ignition-delete-config ran on masked boot"
    fi
    ok "Masked unit OK"
    ;;

*) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}" ;;
esac
