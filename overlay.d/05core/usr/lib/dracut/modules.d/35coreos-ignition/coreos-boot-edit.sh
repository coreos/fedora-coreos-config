#!/bin/bash
set -euo pipefail

# For a description of how this is used, see `coreos-boot-edit.service`.

cmdline=( $(</proc/cmdline) )
karg() {
    local name="$1" value="${2:-}"
    for arg in "${cmdline[@]}"; do
        if [[ "${arg%%=*}" == "${name}" ]]; then
            value="${arg#*=}"
        fi
    done
    echo "${value}"
}

verify_unique_boot() {
    # UUIDs were changed, so there could be a divergence between kernel's
    # and userspace's data. Try checking (with rereading partition table)
    # up to 3 times before giving up
    for i in 1 2; do
        echo "Verifying filesystem labeled 'boot' is unique, try $i"
        rdcore verify-unique-fs-label --rereadpt boot && status=$? || status=$?
        if [[ $status -eq 0 ]]; then
            return 0
        fi
        sleep 1
    done
    echo "Verifying filesystem labeled 'boot' is unique, last try"
    rdcore verify-unique-fs-label --rereadpt boot
}

# Verify that after provision we still have unique boot partition
verify_unique_boot

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
rm -vrf ${initramfs_firstboot_network_dir}

# If root is specified, assume rootmap is already configured. Otherwise,
# append rootmap kargs to the BLS configs.
root=$(karg root)
if [ -z "${root}" ]; then
    rdcore rootmap /sysroot --boot-mount ${bootmnt}
fi

# This does a few things:
# 1. it puts the boot UUID in /run/coreos/bootfs_uuid which is used by the real
#    root for mounting the bootfs in this boot
# 2. it adds a boot=UUID= karg which is used by the real root for mounting the
#    bootfs in subsequent boots
# 3. it create a .root_uuid stamp file on the bootfs or fails if one exists
# 4. it adds GRUB bootuuid.cfg dropins so that GRUB selects the boot filesystem
#    by UUID
rdcore bind-boot /sysroot ${bootmnt}
