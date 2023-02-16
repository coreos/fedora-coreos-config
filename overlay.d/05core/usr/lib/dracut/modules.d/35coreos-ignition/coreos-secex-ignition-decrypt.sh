#!/bin/bash
set -euo pipefail

disk=/dev/disk/by-id/virtio-ignition_crypted
conf=/usr/lib/ignition/user.ign
pkey=/usr/lib/coreos/ignition.asc
tmpd=

cleanup() {
    rm -f "${pkey}"
    if [[ -n "${tmpd}" ]]; then
        rm -rf "${tmpd}"
    fi
}

trap cleanup EXIT

tmpd=$(mktemp -d)

if [ ! -e "${disk}" ]; then
    echo "Ignition config must be encrypted"
    exit 1
fi

gpg --homedir "${tmpd}" --import "${pkey}" && rm "${pkey}"
gpg --homedir "${tmpd}" --skip-verify --output "${conf}" --decrypt "${disk}"
