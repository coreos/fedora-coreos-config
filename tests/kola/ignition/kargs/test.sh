#!/bin/bash
set -xeuo pipefail

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

if ! grep foobar /proc/cmdline; then
    fatal "missing foobar in kernel cmdline"
fi
if grep mitigations /proc/cmdline; then
    fatal "found mitigations in kernel cmdline"
fi
ok "Ignition kargs"
