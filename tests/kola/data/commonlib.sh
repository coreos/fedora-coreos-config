#!/bin/bash

# This is a common library created for the ok & fatal function and symlinks
# added to the data/ in each directory

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

get_ipv4_for_nic() {
    local nic_name=$1
    local ip=$(ip -j addr show ${nic_name} | jq -r '.[0].addr_info | map(select(.family == "inet")) | .[0].local')
    if [ -z "$ip" ]; then
        echo "Error: can not get ip for ${nic_name}"
        exit 1
    fi
    echo $ip
}

get_fcos_stream() {
    rpm-ostree status -b --json | jq -r '.deployments[0]["base-commit-meta"]["fedora-coreos.stream"]'
}
