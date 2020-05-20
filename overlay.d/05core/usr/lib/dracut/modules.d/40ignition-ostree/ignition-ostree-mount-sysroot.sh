#!/bin/bash
set -euo pipefail

# We use prjquota on XFS by default to aid multi-tenant
# Kubernetes (and other container) clusters.  See
# https://github.com/coreos/coreos-assembler/pull/303/commits/6103effbd006bb6109467830d6a3e42dd847668d
# In the future this will be augmented with a check for whether
# or not we've reprovisioned the rootfs, since we don't want to
# force on prjquota there.
rootpath="${ROOT_DEVICE_PATH:-/dev/disk/by-label/root}"

# If root is on a multipath device, we use that one.
# this link is created by our own udev rule.
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
