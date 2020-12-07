#!/bin/bash
set -euo pipefail

# Note that on *new machines* this script is now only ever used on firstboot. On
# subsequent boots, systemd-fstab-generator mounts /sysroot from the
# root=UUID=... and rootflags=... kargs.

# We may do a migration window at some point where older machines have these
# kargs injected so that we can simplify the model further.

rootpath=/dev/disk/by-label/root
if ! [ -b "${rootpath}" ]; then
  echo "ignition-ostree-mount-sysroot: Failed to find ${rootpath}" 1>&2
  exit 1
fi

echo "Mounting ${rootpath} ($(realpath "${rootpath}")) to /sysroot"
mount -o "$(coreos-rootflags)" "${rootpath}" /sysroot
