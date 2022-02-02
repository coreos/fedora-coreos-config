#!/bin/bash
# TODO: Doc

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if ! grep foobar /proc/cmdline; then
    fatal "missing foobar in kernel cmdline"
fi
if grep mitigations /proc/cmdline; then
    fatal "found mitigations in kernel cmdline"
fi
ok "Ignition kargs"
