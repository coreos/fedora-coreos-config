#!/bin/bash
# kola: { "exclusive": false }
# Verifies that the expected iptables backend is configured.
# https://github.com/coreos/fedora-coreos-tracker/issues/676
set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# we're currently rolling out to next first
case "$(get_fcos_stream)" in
    "next-devel" | "next")
        if ! iptables --version | grep nf_tables; then
            iptables --version # output for logs
            fatal "iptables version is not nft"
        fi
        ok "iptables in nft mode"
        ;;
    *)
        # Make sure we're on legacy iptables
        if ! iptables --version | grep legacy; then
            iptables --version # output for logs
            fatal "iptables version is not legacy"
        fi
        ok "iptables in legacy mode"
        ;;
esac
