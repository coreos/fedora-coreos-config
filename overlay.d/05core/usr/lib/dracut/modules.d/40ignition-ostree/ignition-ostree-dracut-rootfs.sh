#!/bin/bash
set -euo pipefail

rootdisk=/dev/disk/by-label/root
rootmnt=/sysroot
tmproot=/run/ignition-ostree-rootfs
saved_rootmnt=${tmproot}/orig-sysroot
memdev=/dev/ram0

# Note that save & restore run in private mount namespaces, hence why we don't
# bother unmounting things here.

case "${1:-}" in
    detect)
        # This is obviously crude; perhaps in the future we could change ignition's `fetch`
        # stage to write out a file if the rootfs is being replaced or so.  But eh, it
        # works for now.
        wipes_rootfs=$(jq '.storage?.filesystems? // [] | map(select(.label == "root" and .wipeFilesystem == true)) | length' < /run/ignition.json)
        if [ "${wipes_rootfs}" = "0" ]; then
            exit 0
        fi
        echo "Detected rootfs replacement in fetched Ignition config: /run/ignition.json"
        mkdir "${tmproot}"
        ;;
    save)
        size=$(lsblk -bn -o SIZE "${rootdisk}")
        sizekbs="$(($size / 1024 + 1))"
        modprobe --first-time brd rd_nr=1 rd_size="$sizekbs" max_part=1
        echo "Moving rootfs to RAM..."
        dd "if=${rootdisk}" "of=${memdev}" bs=8M
        echo "Moved rootfs to RAM, pending redeployment: ${memdev}"
        ;;
    restore)
        mount "$rootdisk" $rootmnt
        echo "Restoring rootfs from RAM..."
        mkdir "${saved_rootmnt}"
        mount "${memdev}" "${saved_rootmnt}"
        rsync -aXHA "${saved_rootmnt}/" "${rootmnt}"
        umount $saved_rootmnt
        rmmod brd
        rm -rf "${tmproot}"
        ;;
    *)
        echo "Unsupported operation: ${1:-}" 1>&2; exit 1
        ;;
esac
