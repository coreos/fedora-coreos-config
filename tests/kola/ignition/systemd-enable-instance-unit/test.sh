#!/bin/bash
set -xeuo pipefail

# This test makes sure that ignition is able to enable instance units.
# https://github.com/coreos/ignition/issues/586
# https://github.com/systemd/systemd/pull/9901

# We don't need to test this on every platform. If it passes in
# one place it will pass everywhere.
# kola: { "platforms": "qemu-unpriv" }

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

# make sure the presets worked and the instantiated unit is enabled
if [ $(systemctl is-enabled echo@foo.service) != 'enabled' ]; then
    fatal "echo@foo.service systemd unit should be enabled"
fi
ok "echo@foo.service systemd unit is enabled"

# make sure the unit ran and wrote 'foo' to the journal
if [ $(journalctl -o cat -u echo@foo.service | sed -n 2p) != 'foo' ]; then
    fatal "echo@foo.service did not write 'foo' to journal"
fi
ok "echo@foo.service ran and wrote 'foo' to the journal"
