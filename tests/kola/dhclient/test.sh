#!/bin/bash
set -xeuo pipefail

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

if ! journalctl -b 0 -u NetworkManager --grep=dhclient | grep -q dhclient; then
    echo "no dhclient logs found" >&2
    fail=1
fi

if [ -z "${fail:-}" ]; then
    ok "success: dhclient is running"
else
    fatal "fail: dhclient not running"
fi
