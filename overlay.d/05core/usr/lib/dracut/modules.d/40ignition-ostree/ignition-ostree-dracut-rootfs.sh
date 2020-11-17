#!/bin/bash
set -euo pipefail

# This is implementation details of Ignition; in the future, we should figure
# out a way to ask Ignition directly whether there's a filesystem with label
# "root" being set up.
ignition_cfg=/run/ignition.json
rootdisk=/dev/disk/by-label/root
saved_sysroot=/run/ignition-ostree-rootfs
partstate=/run/ignition-ostree-rootfs-partstate.json

case "${1:-}" in
    detect)
        wipes_root=$(jq '.storage?.filesystems? // [] | map(select(.label == "root" and .wipeFilesystem == true)) | length' "${ignition_cfg}")
        if [ "${wipes_root}" = "0" ]; then
            exit 0
        fi
        echo "Detected rootfs replacement in fetched Ignition config: /run/ignition.json"
        mkdir "${saved_sysroot}"
        # use 80% of RAM: we want to be greedy since the boot breaks anyway, but
        # we still want to leave room for everything else so it hits ENOSPC and
        # doesn't invoke the OOM killer
        mount -t tmpfs tmpfs "${saved_sysroot}" -o size=80%
        ;;
    save)
        mount "${rootdisk}" /sysroot
        echo "Moving rootfs to RAM..."
        cp -aT /sysroot "${saved_sysroot}"
        # also store the state of the partition
        lsblk "${rootdisk}" --nodeps --paths --json -b -o NAME,SIZE | jq -c . > "${partstate}"
        ;;
    restore)
        # This one is in a private mount namespace since we're not "offically" mounting
        mount "${rootdisk}" /sysroot
        echo "Restoring rootfs from RAM..."
        find "${saved_sysroot}" -mindepth 1 -maxdepth 1 -exec mv -t /sysroot {} \;
        chattr +i $(ls -d /sysroot/ostree/deploy/*/deploy/*/)
        ;;
    cleanup)
        if [ -d "${saved_sysroot}" ]; then
            umount "${saved_sysroot}"
            rm -rf "${saved_sysroot}" "${partstate}"
        fi
        ;;
    *)
        echo "Unsupported operation: ${1:-}" 1>&2; exit 1
        ;;
esac
