#!/bin/bash
set -euo pipefail

# For a description of how this is used, see `coreos-boot-edit.service`.

# Mount /boot. Note that we mount /boot but we don't unmount it because we
# are run in a systemd unit with MountFlags=slave so it is unmounted for us.
bootmnt=/mnt/boot_partition
mkdir -p ${bootmnt}
bootdev=/dev/disk/by-label/boot
mount -o rw ${bootdev} ${bootmnt}

# Clean up firstboot networking config files if the user copied them into the
# installed system (most likely by using `coreos-installer install --copy-network`).
firstboot_network_dir_basename="coreos-firstboot-network"
initramfs_firstboot_network_dir="${bootmnt}/${firstboot_network_dir_basename}"
copy_firstboot_network_stamp="/run/coreos-copy-firstboot-network.stamp"
if [ -f ${copy_firstboot_network_stamp} ]; then
    rm -vrf ${initramfs_firstboot_network_dir}
else
    echo "info: no firstboot networking config files to clean from /boot. skipping"
fi
