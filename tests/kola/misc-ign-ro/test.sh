#!/bin/bash
set -xeuo pipefail

ok() {
        echo "ok" "$@"
    }

fatal() {
        echo "$@" >&2
            exit 1
        }

# This test makes sure that swap on zram devices can be set up
# using the zram-generator as defined in the docs at
# https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-configure-swaponzram/

if ! grep -q 'zram0' /proc/swaps; then
    fatal "expected zram0 to be set up"
fi
ok "swap on zram was set up correctly"

# Make sure that coreos-update-ca-trust kicked in and observe the result.
if ! systemctl show coreos-update-ca-trust.service -p ActiveState | grep ActiveState=active; then
    fatal "coreos-update-ca-trust.service not active"
fi
if ! grep '^# coreos.com$' /etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt; then
    fatal "expected coreos.com in ca-bundle"
fi
ok "coreos-update-ca-trust.service"
