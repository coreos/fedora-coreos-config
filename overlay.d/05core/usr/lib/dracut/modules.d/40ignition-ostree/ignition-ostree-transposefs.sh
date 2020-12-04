#!/bin/bash
set -euo pipefail

# This is implementation details of Ignition; in the future, we should figure
# out a way to ask Ignition directly whether there's a filesystem with label
# "root" being set up.
ignition_cfg=/run/ignition.json
root_part=/dev/disk/by-label/root
boot_part=/dev/disk/by-label/boot
esp_part=/dev/disk/by-label/EFI-SYSTEM
saved_data=/run/ignition-ostree-transposefs
saved_root=${saved_data}/root
saved_boot=${saved_data}/boot
saved_esp=${saved_data}/esp
partstate_root=/run/ignition-ostree-rootfs-partstate.json

# Print jq query string for wiped filesystems with label $1
query_fslabel() {
    echo ".storage?.filesystems? // [] | map(select(.label == \"$1\" and .wipeFilesystem == true))"
}

case "${1:-}" in
    detect)
        # Mounts are not in a private namespace so we can mount ${saved_data}
        wipes_root=$(jq "$(query_fslabel root) | length" "${ignition_cfg}")
        wipes_boot=$(jq "$(query_fslabel boot) | length" "${ignition_cfg}")
        wipes_esp=$(jq "$(query_fslabel EFI-SYSTEM) | length" "${ignition_cfg}")
        if [ "${wipes_root}${wipes_boot}${wipes_esp}" = "000" ]; then
            exit 0
        fi
        echo "Detected partition replacement in fetched Ignition config: /run/ignition.json"
        mkdir "${saved_data}"
        # use 80% of RAM: we want to be greedy since the boot breaks anyway, but
        # we still want to leave room for everything else so it hits ENOSPC and
        # doesn't invoke the OOM killer
        mount -t tmpfs tmpfs "${saved_data}" -o size=80%
        if [ "${wipes_root}" != "0" ]; then
            mkdir "${saved_root}"
        fi
        if [ "${wipes_boot}" != "0" ]; then
            mkdir "${saved_boot}"
        fi
        if [ "${wipes_esp}" != "0" ]; then
            mkdir "${saved_esp}"
        fi
        ;;
    save)
        # Mounts happen in a private mount namespace since we're not "offically" mounting
        if [ -d "${saved_root}" ]; then
            mount "${root_part}" /sysroot
            echo "Moving rootfs to RAM..."
            cp -aT /sysroot "${saved_root}"
            # also store the state of the partition
            lsblk "${root_part}" --nodeps --paths --json -b -o NAME,SIZE | jq -c . > "${partstate_root}"
        fi
        if [ -d "${saved_boot}" ]; then
            mkdir -p /sysroot/boot
            mount "${boot_part}" /sysroot/boot
            echo "Moving bootfs to RAM..."
            cp -aT /sysroot/boot "${saved_boot}"
        fi
        if [ -d "${saved_esp}" ]; then
            mkdir -p /sysroot/boot/efi
            mount "${esp_part}" /sysroot/boot/efi
            echo "Moving EFI System Partition to RAM..."
            cp -aT /sysroot/boot/efi "${saved_esp}"
        fi
        ;;
    restore)
        # Mounts happen in a private mount namespace since we're not "offically" mounting
        if [ -d "${saved_root}" ]; then
            mount "${root_part}" /sysroot
            echo "Restoring rootfs from RAM..."
            find "${saved_root}" -mindepth 1 -maxdepth 1 -exec mv -t /sysroot {} \;
            chattr +i $(ls -d /sysroot/ostree/deploy/*/deploy/*/)
        fi
        if [ -d "${saved_boot}" ]; then
            mkdir -p /sysroot/boot
            mount "${boot_part}" /sysroot/boot
            echo "Restoring bootfs from RAM..."
            find "${saved_boot}" -mindepth 1 -maxdepth 1 -exec mv -t /sysroot/boot {} \;
        fi
        if [ -d "${saved_esp}" ]; then
            echo "Restoring EFI System Partition from RAM..."
            mkdir -p /sysroot/boot/efi
            mount "${esp_part}" /sysroot/boot/efi
            find "${saved_esp}" -mindepth 1 -maxdepth 1 -exec mv -t /sysroot/boot/efi {} \;
        fi
        ;;
    cleanup)
        # Mounts are not in a private namespace so we can unmount ${saved_data}
        if [ -d "${saved_data}" ]; then
            umount "${saved_data}"
            rm -rf "${saved_data}" "${partstate_root}"
        fi
        ;;
    *)
        echo "Unsupported operation: ${1:-}" 1>&2; exit 1
        ;;
esac
