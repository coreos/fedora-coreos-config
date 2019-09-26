#!/bin/bash
set -euo pipefail

rootdisk=/dev/disk/by-label/root
rootmnt=/sysroot
tmproot=/run/ignition-ostree-rootfs
saved_rootmnt=${tmproot}/orig-sysroot
memdev=/dev/ram0

case "${1:-}" in
    detect)
        # This is obviously crude; perhaps in the future we could change ignition's `fetch`
        # stage to write out a file if the rootfs is being replaced or so.  But eh, it
        # works for now.
        has_rootfs=$(jq '.storage?.filesystems? // [] | map(select(.label == "root")) | length' < /run/ignition.json)
        if [ "${has_rootfs}" = "0" ]; then
            exit 0
        fi
        echo "Detected rootfs replacement in fetched Ignition config: /run/ignition.json"
        mkdir "${tmproot}"
        ;;
    save)
        size=$(lsblk -bn -o SIZE "${rootdisk}")
        sizekbs="$(($size / 1024 + 1))"
        if lsmod | grep -q brd; then
            echo 'error: brd module is already loaded' 1>&2; exit 1
        fi
        modprobe brd rd_nr=1 rd_size="$sizekbs" max_part=1
        echo "Moving rootfs to RAM..."
        dd "if=${rootdisk}" "of=${memdev}" bs=8M
        echo "Moved rootfs to RAM, pending redeployment: ${memdev}"
        ;;
    restore)
        # This one is in a private mount namespace since we're not "offically" mounting
        mount "$rootdisk" $rootmnt
        # This can occur when specifying `wipeFilesystem: false`; TODO detect that above
        if [ -d "${rootmnt}/boot" ]; then
            echo "NOTE: Detected Ignition rootfs replacement, but filesystem is not empty"
            exit 0
        fi
        echo "Restoring rootfs from RAM..."
        mkdir "${saved_rootmnt}"
        mount "${memdev}" "${saved_rootmnt}"
        # Remove the immutable bits so we can use `mv`
        chattr -i ${saved_rootmnt} ${saved_rootmnt}/ostree/deploy/*/deploy/*.0
        for x in .coreos-aleph-version.json boot ostree; do
            mv -Tn ${saved_rootmnt}/${x} ${rootmnt}/${x}
        done
        # And restore the immutable bits
        chattr +i ${rootmnt}/ostree/deploy/*/deploy/*.0 ${rootmnt}
        echo "...done"
        umount $rootmnt
        umount $saved_rootmnt
        rmmod brd
        rm -rf "${tmproot}"
        ;;
    *)
        echo "Unsupported operation: ${1:-}" 1>&2; exit 1
        ;;
esac
