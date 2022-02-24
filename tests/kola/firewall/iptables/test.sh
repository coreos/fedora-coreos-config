#!/bin/bash
# kola: { "exclusive": false }
# Verifies that the expected iptables backend is configured.
# https://github.com/coreos/fedora-coreos-tracker/issues/676
set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# rollout is tied to f36+ on FCOS
# RHCOS is already in nft
# once all of FCOS is on f36, we can drop this branching
if is_rhcos || [ "$(get_fedora_ver)" -ge 36 ]; then
    if ! iptables --version | grep nf_tables; then
        iptables --version # output for logs
        fatal "iptables version is not nft"
    fi
    ok "iptables in nft mode"
else
    if ! iptables --version | grep legacy; then
        iptables --version # output for logs
        fatal "iptables version is not legacy"
    fi
    ok "iptables in legacy mode"
fi
