#!/bin/bash
set -euo pipefail

copy_file_if_exists() {
    src="${1}"; dst="${2}"
    if [ -f "${src}" ]; then
        echo "Copying ${src} to ${dst}"
        cp "${src}" "${dst}"
    else
        echo "File ${src} does not exist.. Skipping copy"
    fi
}

destination=/usr/lib/ignition
mkdir -p $destination

karg() {
    local name="$1" value="${2:-}"
    local cmdline=( $(</proc/cmdline) )
    for arg in "${cmdline[@]}"; do
        if [[ "${arg%%=*}" == "${name}" ]]; then
            value="${arg#*=}"
        fi
    done
    echo "${value}"
}

# Copied from
# https://github.com/dracutdevs/dracut/blob/9491e599282d0d6bb12063eddbd192c0d2ce8acf/modules.d/99base/dracut-lib.sh#L586
# rather than sourcing it.
label_uuid_to_dev() {
    local _dev
    _dev="${1#block:}"
    case "$_dev" in
        LABEL=*)
            echo "/dev/disk/by-label/$(echo "${_dev#LABEL=}" | sed 's,/,\\x2f,g;s, ,\\x20,g')"
            ;;
        PARTLABEL=*)
            echo "/dev/disk/by-partlabel/$(echo "${_dev#PARTLABEL=}" | sed 's,/,\\x2f,g;s, ,\\x20,g')"
            ;;
        UUID=*)
            echo "/dev/disk/by-uuid/$(echo "${_dev#UUID=}" | tr "[:upper:]" "[:lower:]")"
            ;;
        PARTUUID=*)
            echo "/dev/disk/by-partuuid/$(echo "${_dev#PARTUUID=}" | tr "[:upper:]" "[:lower:]")"
            ;;
    esac
}

# This is copied from coreos-boot-mount-generator which we should likely run
# in the initramfs too
bootdev=/dev/disk/by-label/boot
bootkarg=$(karg boot)
mpath=$(karg rd.multipath)
if [ -n "${mpath}" ] && [ "${mpath}" != 0 ]; then
    bootdev=/dev/disk/by-label/dm-mpath-boot
# Newer nodes inject boot=UUID=..., but we support a larger subset of the dracut/fips API
elif [ -n "${bootkarg}" ]; then
    # Adapted from https://github.com/dracutdevs/dracut/blob/9491e599282d0d6bb12063eddbd192c0d2ce8acf/modules.d/01fips/fips.sh#L17
    case "$bootkarg" in
        LABEL=* | UUID=* | PARTUUID=* | PARTLABEL=*)
            bootdev="$(label_uuid_to_dev "$bootkarg")";;
        /dev/*) bootdev=$bootkarg;;
        *) echo "Unknown boot karg '${bootkarg}'; falling back to ${bootdev}";;
    esac
# This is used for the first boot only
elif [ -f /run/coreos/bootfs_uuid ]; then
    bootdev=/dev/disk/by-uuid/$(cat /run/coreos/bootfs_uuid)
fi

if is-live-image; then
    # Live image. If the user has supplied a config.ign via an appended
    # initrd, put it in the right place.
    copy_file_if_exists "/config.ign" "${destination}/user.ign"
else
    # We will support a user embedded config in the boot partition
    # under $bootmnt/ignition/config.ign. Note that we mount /boot
    # but we don't unmount boot because we are run in a systemd unit
    # with MountFlags=slave so it is unmounted for us.
    bootmnt=/mnt/boot_partition
    mkdir -p $bootmnt
    # mount as read-only since we don't strictly need write access and we may be
    # running alongside other code that also has it mounted ro
    mount -o ro $bootdev $bootmnt
    copy_file_if_exists "${bootmnt}/ignition/config.ign" "${destination}/user.ign"
fi
