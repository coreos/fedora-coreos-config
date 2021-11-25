#!/bin/bash
set -xeuo pipefail

# This test makes sure that ignition is able to unmask units
# It just so happens we have masked dnsmasq in FCOS so we can
# test this by unmasking it.

# We don't need to test this on every platform. If it passes in
# one place it will pass everywhere.
# This test is currently scoped to FCOS because `dnsmasq` is not masked
# on RHCOS.
# TODO-RHCOS: determine if any services on RHCOS are masked and adapt test
# kola: { "distros": "fcos", "platforms": "qemu-unpriv" }

fatal() {
    echo "$@" >&2
    exit 1
}

# make sure the systemd unit (dnsmasq) is unmasked and enabled
if [ "$(systemctl is-enabled dnsmasq.service)" != 'enabled' ]; then
    fatal "dnsmasq.service systemd unit should be unmasked and enabled"
fi
