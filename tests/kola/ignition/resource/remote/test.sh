#!/bin/bash
## kola:
##   # We fetch resources from S3 and GCS
##   tags: needs-internet
##   # Don't pass AWS or GCP credentials to instance
##   # This test verifies that Ignition can fetch anonymous resources within
##   # a cloud platform (S3 -> EC2, GCS -> GCE) when no credentials are supplied
##   noInstanceCreds: true

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if ! diff -rZ $KOLA_EXT_DATA/expected /var/resource; then
    fatal "fetched data mismatch"
else
    ok "fetched data ok"
fi
