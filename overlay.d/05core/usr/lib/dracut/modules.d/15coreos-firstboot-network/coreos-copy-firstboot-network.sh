#!/bin/bash
set -euo pipefail

# For a description of how this is used see coreos-copy-firstboot-network.service

firstboot_network_dir_basename="coreos-firstboot-network"
initramfs_firstboot_network_dir="/boot/${firstboot_network_dir_basename}"
initramfs_network_dir="/run/NetworkManager/system-connections/"
realroot_firstboot_network_dir="/boot/${firstboot_network_dir_basename}"

if [ -n "$(ls -A ${initramfs_firstboot_network_dir} 2>/dev/null)" ]; then
    # Clear out any files that may have already been generated from
    # kargs by nm-initrd-generator
    rm -f ${initramfs_network_dir}/*
    # Copy files that were placed into boot (most likely by coreos-installer)
    # to the appropriate location for NetworkManager to use the configuration.
    echo "info: copying files from ${initramfs_firstboot_network_dir} to ${initramfs_network_dir}"
    mkdir -p ${initramfs_network_dir}
    cp -v ${initramfs_firstboot_network_dir}/* ${initramfs_network_dir}/
    # If we make it to the realroot (successfully ran ignition) then
    # clean up the files in the firstboot network dir
    echo "R ${realroot_firstboot_network_dir} - - - - -" > \
        /run/tmpfiles.d/15-coreos-firstboot-network.conf
else
    echo "info: no files to copy from ${initramfs_firstboot_network_dir}. skipping"
fi
