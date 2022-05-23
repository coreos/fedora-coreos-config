#!/bin/bash
# kola: { "tags": "needs-internet", "platforms": "gce" }
# - tags: needs-internet
#   - We fetch resources from GCS.
# - platforms: gce
#   - We authenticate to GCS with the GCE instance's credentials.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if ! diff -rZ $KOLA_EXT_DATA/expected /var/resource; then
    fatal "fetched data mismatch"
else
    ok "fetched data ok"
fi

# verify that the objects are inaccessible anonymously
for obj in authenticated authenticated-var.ign; do
    if curl -sf "https://storage.googleapis.com/ignition-test-fixtures/resources/$obj"; then
        fatal "anonymously fetching authenticated resource should have failed, but did not"
    fi
done

# ...but that the anonymous object is accessible
if ! curl -sf "https://storage.googleapis.com/ignition-test-fixtures/resources/anonymous" > /dev/null; then
    fatal "anonymous resource is inaccessible"
fi

ok "resource checks ok"
