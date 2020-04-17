#!/bin/bash
set -euo pipefail

# For a description of how this is used see coreos-copy-firstboot-network.service

bootmnt=/mnt/boot_partition
mkdir -p ${bootmnt}
bootdev=/dev/disk/by-label/boot
firstboot_network_dir_basename="coreos-firstboot-network"
initramfs_firstboot_network_dir="${bootmnt}/${firstboot_network_dir_basename}"
initramfs_network_dir="/run/NetworkManager/system-connections/"
realroot_firstboot_network_dir="/boot/${firstboot_network_dir_basename}"

# Mount /boot. Note that we mount /boot but we don't unmount boot because we
# are run in a systemd unit with MountFlags=slave so it is unmounted for us.
# Mount as read-only since we don't strictly need write access and we may be
# running alongside other code that also has it mounted ro
mountboot() {
    # Wait for up to 5 seconds for the boot device to be available
    # The After=...*boot.device in the systemd unit should be enough
    # but there appears to be some race in the kernel where the link under
    # /dev/disk/by-label exists but mount is not able to use the device yet.
    # We saw errors like this in CI:
    #
    #   [    4.045181] systemd[1]: Found device /dev/disk/by-label/boot.
    #   [  OK  ] Found device /dev/disk/by-label/boot
    #   [    4.051500] systemd[1]: Starting Copy CoreOS Firstboot Networking Config...
    #         Starting  Copy CoreOS Firstboot Networking Config
    #   [    4.060573]  vda: vda1 vda2 vda3 vda4
    #   [    4.063296] coreos-copy-firstboot-network[479]: mount: /mnt/boot_partition: special device /dev/disk/by-label/boot does not exist.
    #
    mounted=0
    for x in {1..5}; do
        if mount -o ro ${bootdev} ${bootmnt}; then
            echo "info: ${bootdev} successfully mounted."
            mounted=1
            break
        else
            echo "info: retrying ${bootdev} mount in 1 second..."
            sleep 1
        fi
    done
    if [ "${mounted}" == "0" ]; then
        echo "error: ${bootdev} mount did not succeed" 1>&2
        return 1
    fi
}

mountboot || exit 1

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
