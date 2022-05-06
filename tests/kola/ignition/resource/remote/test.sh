#!/bin/bash
# kola: { "tags": "needs-internet" }

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if ! diff -rZ $KOLA_EXT_DATA/expected /var/resource; then
    fatal "fetched data mismatch"
else
    ok "fetched data ok"
fi
