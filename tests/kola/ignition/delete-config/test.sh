#!/bin/bash
## kola:
##   platforms: qemu
##   description: Verify that we delete userdata from provider after Ignition
##     completes.

# See https://github.com/coreos/ignition/issues/1315
# There are 2 services:
# 1)ignition-delete-config.service, which deletes Ignition
# configs from VMware and VirtualBox on first boot.
# 2)coreos-ignition-delete-config.service, do the same thing
# on existing machines on upgrade, using a stamp file in /var/lib
# to avoid multiple runs.
# Ideally we'd test on virtualbox and vmware, but we don't have tests
# there, so we mock specifically for ignition.platform.id=qemu.
# Test scenarios:
# On first boot, verify that both 2 services ran.
# On upgrade boot, verify that 1) should not run, 2) should run.
# On normal boot, verify that both 2 services should not run.
# On upgrade boot with 2) masked, verify that both 2 services
# should not run.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
"")
    # Ignition boot

    # https://github.com/coreos/ignition/issues/1833
    if [ $(stat --format="%a" /etc/systemd/system/ignition-delete-config.service.d/50-kola.conf) != "644" ]; then
        fatal "dropin file permission should be 644"
    fi
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
