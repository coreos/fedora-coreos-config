#!/bin/bash
set -euo pipefail

# This script is run by ignition-ostree-growfs.service. It grows the root
# partition, unless it determines that either the rootfs was moved or the
# partition was already resized (e.g. via Ignition).

# If root reprovisioning was triggered, this file contains state of the root
# partition *before* ignition-disks.
saved_partstate=/run/ignition-ostree-rootfs-partstate.sh

# We run after the rootfs is mounted at /sysroot, but before ostree-prepare-root
# moves it to /sysroot/sysroot.
path=/sysroot

# The use of tail is to avoid errors from duplicate mounts;
# this shouldn't happen for us but we're being conservative.
src=$(findmnt -nvr -o SOURCE "$path" | tail -n1)

if [ ! -f "${saved_partstate}" ]; then
    partition=$(realpath /dev/disk/by-label/root)
else
    # The rootfs was reprovisioned. Our rule in this case is: we only grow if
    # the partition backing the rootfs is the same and its size didn't change
    # (IOW, it was an in-place reprovisioning; e.g. LUKS or xfs -> btrfs).
    source "${saved_partstate}"
    if [ "${TYPE}" != "part" ]; then
        # this really should never happen; but play nice
        echo "$0: original rootfs blockdev not of type 'part'; not auto-growing"
        exit 0
    fi
    partition=$(realpath "${NAME}")
    if [ "${SIZE}" != "$(lsblk --nodeps -bno SIZE "${partition}")" ]; then
        echo "$0: original root partition changed size; not auto-growing"
        exit 0
    fi
    if ! lsblk -no MOUNTPOINT "${partition}" | grep -q '^/sysroot$'; then
        echo "$0: original root partition no longer backing rootfs; not auto-growing"
        exit 0
    fi
fi

# Go through each blockdev in the hierarchy and verify we know how to grow them
lsblk -no TYPE "${partition}" | while read dev; do
    case "${dev}" in
        part|crypt) ;;
        *) echo "error: Unsupported blockdev type ${dev}" 1>&2; exit 1 ;;
    esac
done

# Get the filesystem type before extending the partition.  This matters
# because the partition, once extended, might include leftover superblocks
# from the previous contents of the disk (notably ZFS), causing blkid to
# refuse to return any filesystem type at all.
eval $(blkid -o export "${src}")
ROOTFS_TYPE=${TYPE:-}
case "${ROOTFS_TYPE}" in
    xfs|ext4|btrfs) ;;
    *) echo "error: Unsupported filesystem for ${path}: '${ROOTFS_TYPE}'" 1>&2; exit 1 ;;
esac

# Now, go through the hierarchy, growing everything. Note we go one device at a
# time using --nodeps, because ordering is buggy in el8:
# https://bugzilla.redhat.com/show_bug.cgi?id=1940607
current_blkdev=${partition}
while true; do
    eval "$(lsblk --paths --nodeps --pairs -o NAME,TYPE,PKNAME "${current_blkdev}")"
    MAJMIN=$(echo $(lsblk -dno MAJ:MIN "${NAME}"))
    case "${TYPE}" in
        part)
            eval $(udevadm info --query property --export "${current_blkdev}" | grep ^DM_ || :)
            if [ -n "${DM_MPATH:-}" ]; then
                # Since growpart does not understand device mapper, we have to use sfdisk.
                echo ", +" | sfdisk --no-reread --no-tell-kernel --force -N "${DM_PART}" "/dev/mapper/${DM_MPATH}"
                udevadm settle # Wait for udev-triggered kpartx to update mappings
            else
                partnum=$(cat "/sys/dev/block/${MAJMIN}/partition")
                # XXX: ideally this'd be idempotent and we wouldn't `|| :`
                growpart "${PKNAME}" "${partnum}" || :
            fi
            ;;
        crypt)
            # XXX: yuck... we need to expose this sanely in clevis
            (. /usr/bin/clevis-luks-common-functions
             eval $(udevadm info --query=property --export "${NAME}")
             # lsblk doesn't print PKNAME of crypt devices with --nodeps
             PKNAME=/dev/$(ls "/sys/dev/block/${MAJMIN}/slaves")
             clevis_luks_unlock_device "${PKNAME}" | cryptsetup resize -d- "${DM_NAME}"
            )
            ;;
        # already checked
        *) echo "unreachable" 1>&2; exit 1 ;;
    esac
    holders="/sys/dev/block/${MAJMIN}/holders"
    [ -d "${holders}" ] || break
    nholders="$(ls "${holders}" | wc -l)"
    if [ "${nholders}" -eq 0 ]; then
        break
    elif [ "${nholders}" -gt 1 ]; then
        # this shouldn't happen since we've checked the partition types already
        echo "error: Unsupported block device with multiple children: ${NAME}" 1>&2
        exit 1
    fi
    current_blkdev=/dev/$(ls "${holders}")
done

# Wipe any filesystem signatures from the extended partition that don't
# correspond to the FS type we detected earlier.
wipefs -af -t "no${ROOTFS_TYPE}" "${src}"

# TODO: Add XFS to https://github.com/systemd/systemd/blob/master/src/partition/growfs.c
# and use it instead.
case "${ROOTFS_TYPE}" in
    xfs) xfs_growfs "${path}" ;;
    ext4) resize2fs "${src}" ;;
    btrfs) btrfs filesystem resize max ${path} ;;
esac

# this is useful for tests
touch /run/ignition-ostree-growfs.stamp
