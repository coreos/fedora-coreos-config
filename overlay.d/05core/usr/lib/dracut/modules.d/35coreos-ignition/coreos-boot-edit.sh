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

# And similarly, only inject boot= if it's not already present.
boot=$(karg boot)
if [ -z "${boot}" ]; then
    # XXX: `rdcore rootmap --inject-boot-karg` or maybe `rdcore bootmap`
    eval $(blkid -o export "${bootdev}")
    if [ -z "${UUID}" ]; then
        # This should never happen
        echo "Boot filesystem ${bootdev} has no UUID" >&2
        exit 1
    fi
    rdcore kargs --boot-mount ${bootmnt} --append boot=UUID=${UUID}
    # but also put it in /run for the first boot real root mount
    mkdir -p /run/coreos
    echo "${UUID}" > /run/coreos/bootfs_uuid
fi
