#!/bin/bash
## kola:
##   tags: needs-internet
##   # Don't pass AWS or GCP credentials to instance
##   noInstanceCreds: true
##   description: Verify that Ignition can fetch anonymous resources within a
##     cloud platform (S3 -> AWS, GCS -> GCP) when no credentials are supplied.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if ! diff -rZ $KOLA_EXT_DATA/expected /var/resource; then
    fatal "fetched data mismatch"
else
    ok "fetched data ok"
fi
