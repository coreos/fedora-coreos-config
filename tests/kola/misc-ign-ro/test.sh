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
