#!/bin/bash
set -euo pipefail

# see related comment block in transposefs.sh re. inspecting the config directly
ignition_cfg=/run/ignition.json
rootpath=/dev/disk/by-label/root

query_rootfs() {
    local filter=$1
    jq -re ".storage?.filesystems? // [] |
                map(select(.label == \"root\" and .wipeFilesystem == true)) |
                .[0] | $filter" "${ignition_cfg}"
}

# If the rootfs was reprovisioned, then the mountOptions from the Ignition
# config has priority.
if [ -d /run/ignition-ostree-transposefs/root ]; then
    if query_rootfs 'has("mountOptions")' >/dev/null; then
        query_rootfs '.mountOptions | join(",")'
        exit 0
    fi
fi

eval $(blkid -p -o export ${rootpath})
if [ "${TYPE}" == "xfs" ]; then
    # We use prjquota on XFS by default to aid multi-tenant Kubernetes (and
    # other container) clusters.  See
    # https://github.com/coreos/coreos-assembler/pull/303/commits/6103effbd006bb6109467830d6a3e42dd847668d
    echo "prjquota"
fi
