#!/bin/bash
set -xeuo pipefail

# To test https://bugzilla.redhat.com/show_bug.cgi?id=1980679
# remote.ign on github: inject kernelArguments and write something to /etc/testfile
# config.ign to include remote kargsfile.ign

# This case need to access remote.ign on github
# qemu-unpriv machines cannot communicate to network
# kola: { "platforms": "! qemu-unpriv", "tags": "needs-internet" }

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

if ! grep -q foobar /proc/cmdline; then
    fatal "missing foobar in kernel cmdline"
else
    ok "find foobar in kernel cmdline"
fi
if ! test -e /etc/testfile; then
    fatal "not found /etc/testfile"
else
    ok "find expected file /etc/testfile"
fi
ok "Ignition remote config test"
