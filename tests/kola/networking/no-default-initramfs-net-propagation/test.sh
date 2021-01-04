#!/bin/bash
set -xeuo pipefail

# With pure network defaults no networking should have been propagated
# from the initramfs. This test tries to verify that is the case.
# https://github.com/coreos/fedora-coreos-tracker/issues/696

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

if ! journalctl -t coreos-teardown-initramfs | \
       grep 'info: skipping propagation of default networking configs'; then
    echo "no log message claiming to skip initramfs network propagation" >&2
    fail=1
fi

if [ -n "$(ls -A /etc/NetworkManager/system-connections/)" ]; then
    echo "configs exist in /etc/NetworkManager/system-connections/, but shouldn't" >&2
    fail=1
fi

if [ -z "${fail:-}" ]; then
    ok "success: no initramfs network propagation for default configuration"
else
    fatal "fail: no initramfs network propagation for default configuration"
fi
