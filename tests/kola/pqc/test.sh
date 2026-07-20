#!/bin/bash
## kola:
##   tags: "needs-internet"
##   description: Check that PQC algorithms are prioritised by default (TLS)
##   creationDate: 2026-06-11

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if ! is_fcos && match_maj_ver "9"; then
    ok "Skipping: PQC not in DEFAULT crypto policy on rhcos9 and c9s"
    exit 0
fi

# A list of websites all which support PQC algorithms
pqcsites=(
    "https://cloud.google.com"
    "https://aws.amazon.com/"
    "https://start.fedoraproject.org/"
)

for site in "${pqcsites[@]}"; do
    tls_info=$(curl -vis --retry 5 -o /dev/null "$site" 2>&1 | grep "SSL connection" || true)
    if ! echo "$tls_info" | grep -q "MLKEM"; then
        fatal "PQC key exchange not negotiated for $site: $tls_info"
    fi
done

ok "All TLS connections used PQC safe algorithms"
