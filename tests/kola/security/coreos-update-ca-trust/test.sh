#!/bin/bash
## kola:
##   exclusive: false
##   description: Verify that coreos-update-ca-trust service works.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# Make sure that coreos-update-ca-trust kicked in and observe the result.
if ! systemctl show coreos-update-ca-trust.service -p ActiveState | grep ActiveState=active; then
    fatal "coreos-update-ca-trust.service not active"
fi
if ! grep '^# coreos.com$' /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; then
    fatal "expected coreos.com certificate not found in tls-ca-bundle.pem"
fi
ok "coreos-update-ca-trust.service"
