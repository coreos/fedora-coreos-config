#!/bin/bash
# kola: { "distros": "fcos", "platforms": "qemu-unpriv" }
# This test makes sure that ignition is able to disable units
# https://github.com/coreos/fedora-coreos-tracker/issues/392

# We don't need to test this on every platform. If it passes in
# one place it will pass everywhere.
# This test is currently scoped to FCOS because `zincati` is only available on
# FCOS.
# TODO-RHCOS: Determine if any services on RHCOS may be disabled and adapt test

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if [ "$(systemctl is-enabled zincati.service)" != 'disabled' ]; then
    fatal "zincati.service systemd unit should be disabled"
fi
ok "zincati.service systemd unit is enabled"
