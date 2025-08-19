#!/bin/bash
## kola:
##   tags: needs-internet
##   # We authenticate to Azure with the Azure instance's credentials.
##   platforms: azure
##   description: Verify that we can fetch resources from Azure.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if ! diff -rZ $KOLA_EXT_DATA/expected /var/resource; then
    fatal "fetched data mismatch"
else
    ok "fetched data ok"
fi

# verify that the objects are inaccessible anonymously
for obj in authenticated authenticated-var.ign; do
    if curl -sf "https://ignitiontestfixtures.blob.core.windows.net/private/$obj"; then
        fatal "anonymously fetching authenticated resource should have failed, but did not"
    fi
done

# ...but that the anonymous object is accessible
if ! curl -sf "https://ignitiontestfixtures.blob.core.windows.net/public/azure-anon" > /dev/null; then
    fatal "anonymous resource is inaccessible"
fi

ok "resource checks ok"
