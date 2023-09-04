#!/bin/bash
## kola:
##   platforms: qemu
##   description: Verify Ignition supports kernel arguments.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if ! grep foobar /proc/cmdline; then
    fatal "missing foobar in kernel cmdline"
fi
if grep mitigations /proc/cmdline; then
    fatal "found mitigations in kernel cmdline"
fi
ok "Ignition kargs"
