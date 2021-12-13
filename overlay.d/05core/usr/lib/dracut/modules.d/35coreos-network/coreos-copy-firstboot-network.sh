#!/bin/bash
set -euo pipefail

# For a description of how this is used see coreos-copy-firstboot-network.service

bootmnt=/mnt/boot_partition
bootdev=/dev/disk/by-label/boot
firstboot_network_dir_basename="coreos-firstboot-network"
boot_firstboot_network_dir="${bootmnt}/${firstboot_network_dir_basename}"
etc_firstboot_network_dir="/etc/${firstboot_network_dir_basename}"
initramfs_network_dir="/run/NetworkManager/system-connections/"

copy_firstboot_network() {
    local src=$1; shift

    # Clear out any files that may have already been generated from
    # kargs by nm-initrd-generator
    rm -f ${initramfs_network_dir}/*
    # Copy files that were placed into the source
    # to the appropriate location for NetworkManager to use the configuration.
    echo "info: copying files from ${src} to ${initramfs_network_dir}"
    mkdir -p ${initramfs_network_dir}
    cp -v ${src}/* ${initramfs_network_dir}/
}

if ! is-live-image; then
    # Mount /boot. Note that we mount /boot but we don't unmount boot because we
    # are run in a systemd unit with MountFlags=slave so it is unmounted for us.
    # Mount as read-only since we don't strictly need write access and we may be
    # running alongside other code that also has it mounted ro
    mkdir -p ${bootmnt}
    mount -o ro ${bootdev} ${bootmnt}

    if [ -n "$(ls -A ${boot_firstboot_network_dir} 2>/dev/null)" ]; then
        # Likely placed there by coreos-installer, see:
        # https://github.com/coreos/coreos-installer/pull/212
        copy_firstboot_network "${boot_firstboot_network_dir}"
    else
        echo "info: no files to copy from ${boot_firstboot_network_dir}; skipping"
    fi
else
    if [ -n "$(ls -A ${etc_firstboot_network_dir} 2>/dev/null)" ]; then
        # Also placed there by coreos-installer but in a different flow, see:
        # https://github.com/coreos/coreos-installer/pull/713
        copy_firstboot_network "${etc_firstboot_network_dir}"
    else
        echo "info: no files to copy from ${etc_firstboot_network_dir}; skipping"
    fi
fi
