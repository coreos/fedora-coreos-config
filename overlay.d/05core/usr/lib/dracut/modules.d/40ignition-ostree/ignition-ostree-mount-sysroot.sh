#!/bin/bash
set -euo pipefail

# We use prjquota on XFS by default to aid multi-tenant
# Kubernetes (and other container) clusters.  See
# https://github.com/coreos/coreos-assembler/pull/303/commits/6103effbd006bb6109467830d6a3e42dd847668d
# In the future this will be augmented with a check for whether
# or not we've reprovisioned the rootfs, since we don't want to
# force on prjquota there.
rootpath=/dev/disk/by-label/root
eval $(blkid -o export ${rootpath})
mountflags=
if [ "${TYPE}" == "xfs" ]; then
  mountflags=prjquota
fi
# in case of using multipath devices, we need to make sure all
# /dev/disk/by-label/ links are fully populated and updated.
udevadm trigger --type=subsystems --action=add
udevadm trigger --type=devices --action=add
udevadm settle
mount -o "${mountflags}" "${rootpath}" /sysroot
