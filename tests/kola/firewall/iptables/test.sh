#!/bin/bash
## kola:
##   exclusive: false
##   description: Verify that the expected iptables backend is configured.

# https://github.com/coreos/fedora-coreos-tracker/issues/676

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if ! iptables --version | grep nf_tables; then
    iptables --version # output for logs
    fatal "iptables version is not nft"
fi
ok "iptables in nft mode"
