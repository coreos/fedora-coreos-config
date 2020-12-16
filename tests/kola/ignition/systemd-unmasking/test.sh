#!/bin/bash
set -xeuo pipefail

# This test makes sure that ignition is able to unmask units
# It just so happens we have masked dnsmasq in FCOS so we can
# test this by unmasking it.

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

# make sure the systemd unit (dnsmasq) is unmasked and enabled
if [ $(systemctl is-enabled dnsmasq.service) != 'enabled' ]; then
    fatal "dnsmasq.service systemd unit should be unmasked and enabled"
fi
ok "dnsmasq.service systemd unit is unmasked and enabled"
