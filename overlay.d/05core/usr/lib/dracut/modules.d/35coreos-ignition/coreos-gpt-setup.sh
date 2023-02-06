#!/bin/bash
# randomizes the disk guid on the disk containing the partition specified by $1
# and moves the secondary gpt header/partition table to the end of the disk where it
# should be. If the disk guid is already randomized, it does nothing.
set -euo pipefail

UNINITIALIZED_GUID='00000000-0000-4000-a000-000000000001'

# If it's on multipath, get the parent device from udev properties.
DM_MPATH=$(eval $(udevadm info --query property --export "$1") && echo "${DM_MPATH:-}")

if [ -n "${DM_MPATH:-}" ]; then
    PKNAME=/dev/mapper/$DM_MPATH
    PTUUID=$(eval $(udevadm info --query property --export "$PKNAME") && echo "${ID_PART_TABLE_UUID:-}")
else
    # On RHEL 8 the version of lsblk doesn't have PTUUID. Let's detect
    # if lsblk supports it. In the future we can remove the 'if' and
    # just use the 'else'.
    if ! lsblk --help | grep -q PTUUID; then
        # Get the PKNAME
        eval $(lsblk --output PKNAME --pairs --paths --nodeps "$1")
        # Get the PTUUID
        eval $(blkid -p -o export $PKNAME)
    else
        # PTUUID is the disk guid, PKNAME is the parent kernel name
        eval $(lsblk --output PTUUID,PKNAME --pairs --paths --nodeps "$1")
    fi
fi

# Skip in the following two cases:
#  - The PTUUID is != $UNINITIALIZED_GUID
#  - The PTUUID is empty. This happens on s390x where DASD disks don't
#    have PTUUID or any of the other traditional partition table
#    attributes of GPT disks.
if [ "${PTUUID:-}" != "$UNINITIALIZED_GUID" ]; then
    echo "Not randomizing disk GUID; found ${PTUUID:-none}"
    exit 0
fi

echo "Randomizing disk GUID"
sgdisk --disk-guid=R --move-second-header "$PKNAME"
udevadm settle || :
