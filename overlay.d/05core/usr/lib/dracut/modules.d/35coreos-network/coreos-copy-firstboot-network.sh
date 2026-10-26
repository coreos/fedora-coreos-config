#!/bin/bash
set -euo pipefail

# For a description of how this is used see coreos-copy-firstboot-network.service

firstboot_network_dir_basename="coreos-firstboot-network"
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

if [ -n "$(ls -A ${etc_firstboot_network_dir} 2>/dev/null)" ]; then
    # coreos-installer always copies to /etc/coreos-firstboot-network
    copy_firstboot_network "${etc_firstboot_network_dir}"
else
    echo "info: no files to copy from ${etc_firstboot_network_dir}; skipping"
fi
