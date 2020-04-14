#!/bin/bash
set -euo pipefail

# We use prjquota on XFS by default to aid multi-tenant
# Kubernetes (and other container) clusters.  See
# https://github.com/coreos/coreos-assembler/pull/303/commits/6103effbd006bb6109467830d6a3e42dd847668d
# In the future this will be augmented with a check for whether
# or not we've reprovisioned the rootfs, since we don't want to
# force on prjquota there.
rootpath=$(lsblk --list --paths --output LABEL,NAME | grep mapper | grep root | awk '{print $2}') || echo -n ''
if [ -z $rootpath ]; then
    rootpath="/dev/disk/by-label/root"
fi
if ! [ -b "${rootpath}" ]; then
  echo "ignition-ostree-mount-sysroot: Failed to find ${rootpath}" 1>&2
  exit 1
fi
eval $(blkid -o export ${rootpath})
mountflags=
if [ "${TYPE}" == "xfs" ]; then
  mountflags=prjquota
fi
mount -o "${mountflags}" "${rootpath}" /sysroot
