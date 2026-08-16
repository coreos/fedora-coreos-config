#!/bin/bash
set -euo pipefail

# For a description of how this is used, see `coreos-boot-edit.service`.

IFS=" " read -r -a cmdline <<< "$(</proc/cmdline)"
karg() {
    local name="$1" value="${2:-}"
    for arg in "${cmdline[@]}"; do
        if [[ "${arg%%=*}" == "${name}" ]]; then
            value="${arg#*=}"
        fi
    done
    echo "${value}"
}

# Prefer the boot partition on the same disk as the already-mounted rootfs.
# /dev/disk/by-label/boot is ambiguous when other disks also carry LABEL=boot
# (e.g. leftover Fibre Channel LUNs). Using the wrong bootfs here makes
# `rdcore bind-boot` stamp GRUB/`boot=UUID=` onto that foreign filesystem
# while root stays on the install disk.
# See: https://github.com/coreos/fedora-coreos-tracker/issues/976
resolve_bootdev() {
    local rootdev diskpath bootdev="" name typ

    rootdev=$(awk '$2 == "/sysroot" { print $1; exit }' /proc/mounts)
    rootdev=${rootdev%%\[*}

    if [[ -n "${rootdev}" && -e "${rootdev}" ]]; then
        # Walk to the whole-disk device (handles partition and simple LUKS).
        diskpath=""
        while read -r name typ; do
            if [[ "${typ}" == "disk" ]]; then
                diskpath="${name}"
            fi
        done < <(lsblk -nsrpn -o NAME,TYPE "${rootdev}" 2>/dev/null || true)

        if [[ -n "${diskpath}" ]]; then
            bootdev=$(lsblk -rpn -o NAME,PARTLABEL "${diskpath}" \
                | awk '$2 == "boot" { print $1; exit }')
            if [[ -z "${bootdev}" ]]; then
                bootdev=$(lsblk -rpn -o NAME,LABEL "${diskpath}" \
                    | awk '$2 == "boot" { print $1; exit }')
            fi
        fi
    fi

    if [[ -n "${bootdev}" ]]; then
        echo "${bootdev}"
        return 0
    fi

    # Last resort: unique-boot.service should already have failed if several
    # LABEL=boot devices exist. Keep this fallback for unusual layouts.
    echo /dev/disk/by-label/boot
}

# Mount /boot. Note that we mount /boot but we don't unmount it because we
# are run in a systemd unit with MountFlags=slave so it is unmounted for us.
bootmnt=/sysroot/boot
bootdev=$(resolve_bootdev)
echo "coreos-boot-edit: mounting boot from ${bootdev}"
mount -o rw "${bootdev}" "${bootmnt}"

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
    echo "Prepared rootmap"
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

# relabel files rdcore created; ideally in the future rdcore does this itself
coreos-relabel /boot/.root_uuid
if [ -e /sysroot/boot/grub2/bootuuid.cfg ]; then
    coreos-relabel /boot/grub2/bootuuid.cfg
fi
