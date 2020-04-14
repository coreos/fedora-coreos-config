#!/bin/bash
set -euo pipefail

# For a description of how this is used see coreos-copy-firstboot-network.service

bootmnt=/mnt/boot_partition
firstboot_network_dir="${bootmnt}/coreos-firstboot-network/"
initramfs_network_dir="/run/NetworkManager/system-connections/"

# Mount /boot. Note that we mount /boot but we don't unmount boot because we
# are run in a systemd unit with MountFlags=slave so it is unmounted for us.
mkdir -p ${bootmnt}
# mount as read-only since we don't strictly need write access and we may be
# running alongside other code that also has it mounted ro
mount -o ro /dev/disk/by-label/boot ${bootmnt}

if [ -n "$(ls -A ${firstboot_network_dir} 2>/dev/null)" ]; then
    # Clear out any files that may have already been generated from
    # kargs by nm-initrd-generator
    rm -f ${initramfs_network_dir}/*
    # Copy files that were placed into boot (most likely by coreos-installer)
    # to the appropriate location for NetworkManager to use the configuration.
    echo "info: copying files from ${firstboot_network_dir} to ${initramfs_network_dir}"
    mkdir -p ${initramfs_network_dir}
    cp -v ${firstboot_network_dir}/* ${initramfs_network_dir}/
else
    echo "info: no files to copy from ${firstboot_network_dir}. skipping"
fi
