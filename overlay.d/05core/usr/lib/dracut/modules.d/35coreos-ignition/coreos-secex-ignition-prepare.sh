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

# copy base Secure Execution config (enables LUKS+dm-verity for boot and root partitions)
cp /usr/lib/coreos/01-secex.ign /usr/lib/ignition/base.d/01-secex.ign

# decrypt user's config
tmpd=$(mktemp -d)

if [ ! -e "${disk}" ]; then
    echo "Ignition config must be encrypted"
    exit 1
fi

gpg --homedir "${tmpd}" --import "${pkey}" && rm "${pkey}"
gpg --homedir "${tmpd}" --skip-verify --output "${conf}" --decrypt "${disk}"
