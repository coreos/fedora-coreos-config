#!/bin/bash
set -euo pipefail

rootpath=/dev/disk/by-label/root

eval $(blkid -o export ${rootpath})
if [ "${TYPE}" == "xfs" ]; then
    # We use prjquota on XFS by default to aid multi-tenant Kubernetes (and
    # other container) clusters.  See
    # https://github.com/coreos/coreos-assembler/pull/303/commits/6103effbd006bb6109467830d6a3e42dd847668d
    echo "prjquota"
fi
