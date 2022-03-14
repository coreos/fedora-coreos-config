#!/bin/bash
# kola: { "distros": "fcos", "exclusive": true }
# This test verifies that one can configure a node to use the legacy iptables
# backend. It is scoped to only FCOS because RHCOS only supports nft.
set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# Make sure we're on legacy iptables
if ! iptables --version | grep legacy; then
    iptables --version # output for logs
    fatal "iptables version is not legacy"
fi
ok "iptables in legacy mode"
