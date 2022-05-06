#!/bin/bash
# kola: { "tags": "needs-internet", "platforms": "aws" }

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if ! diff -rZ $KOLA_EXT_DATA/expected /var/resource; then
    fatal "fetched data mismatch"
else
    ok "fetched data ok"
fi

# verify that the objects are inaccessible anonymously
for obj in authenticated authenticated.ign; do
    if curl -sf "https://rh-kola-fixtures.s3.amazonaws.com/resources/$obj"; then
        fatal "anonymously fetching authenticated resource should have failed, but did not"
    fi
done

# ...but that the anonymous object is accessible
if ! curl -sf "https://rh-kola-fixtures.s3.amazonaws.com/resources/anonymous" > /dev/null; then
    fatal "anonymous resource is inaccessible"
fi

ok "resource checks ok"
