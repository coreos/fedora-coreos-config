#!/bin/bash
set -euo pipefail

# This script is run by ignition-ostree-growfs.service. It grows the root
# partition, unless it determines that either the rootfs was moved or the
# partition was already resized (e.g. via Ignition).

# If root reprovisioning was triggered, this file contains state of the root
# partition *before* ignition-disks.
saved_partstate=/run/ignition-ostree-rootfs-partstate.json

# We run after the rootfs is mounted at /sysroot, but before ostree-prepare-root
# moves it to /sysroot/sysroot.
path=/sysroot

# The use of tail is to avoid errors from duplicate mounts;
# this shouldn't happen for us but we're being conservative.
src=$(findmnt -nvr -o SOURCE "$path" | tail -n1)

if [ -f "${saved_partstate}" ]; then
    # We're still ironing out our rootfs automatic growpart story, see e.g.:
    # https://github.com/coreos/fedora-coreos-tracker/issues/570
    # https://github.com/coreos/fedora-coreos-tracker/issues/586
    #
    # In the context of rootfs reprovisioning, for now our rule is the
    # following: if the rootfs partition was moved off of the boot disk or it
    # was resized, then we don't growpart.
    #
    # To detect this, we compare the output of `lsblk --paths -o NAME,SIZE`
    # before and after `ignition-disks.service`.
    partstate=$(lsblk "${src}" --nodeps --paths --json -b -o NAME,SIZE | jq -c .)
    if [ "${partstate}" != "$(cat "${saved_partstate}")" ]; then
        echo "coreos-growpart: detected rootfs partition changes; not auto-growing"
        exit 0
    fi
fi

# Get the filesystem type before extending the partition.  This matters
# because the partition, once extended, might include leftover superblocks
# from the previous contents of the disk (notably ZFS), causing blkid to
# refuse to return any filesystem type at all.
eval $(blkid -o export "${src}")
case "${TYPE:-}" in
    xfs|ext4|btrfs) ;;
    *) echo "error: Unsupported filesystem for ${path}: '${TYPE:-}'" 1>&2; exit 1 ;;
esac

if test "${TYPE:-}" = "btrfs"; then
    # Theoretically btrfs can have multiple devices, but when
    # we start we will always have exactly one.
    devpath=$(btrfs device usage /sysroot | grep /dev | cut -f 1 -d ,)
    devpath=$(realpath /sys/class/block/${devpath#/dev/})
else
    # Handle traditional disk/partitions
    majmin=$(findmnt -nvr -o MAJ:MIN "$path" | tail -n1)
    devpath=$(realpath "/sys/dev/block/$majmin")
fi
partition="${partition:-$(cat "$devpath/partition")}"
parent_path=$(dirname "$devpath")
parent_device=/dev/$(basename "${parent_path}")

# TODO: make this idempotent, and don't error out if
# we can't resize.
growpart "${parent_device}" "${partition}" || true

# Wipe any filesystem signatures from the extended partition that don't
# correspond to the FS type we detected earlier.
wipefs -af -t "no${TYPE}" "${src}"

# TODO: Add XFS to https://github.com/systemd/systemd/blob/master/src/partition/growfs.c
# and use it instead.
case "${TYPE}" in
    xfs) xfs_growfs "${path}" ;;
    ext4) resize2fs "${src}" ;;
    btrfs) btrfs filesystem resize max ${path} ;;
esac

# this is useful for tests
touch /run/ignition-ostree-growfs.stamp
