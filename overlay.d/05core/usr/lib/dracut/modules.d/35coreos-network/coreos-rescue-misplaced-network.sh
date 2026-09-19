#!/bin/bash
set -euo pipefail

# Rescue firstboot network config that an older coreos-installer placed
# in /boot/coreos-firstboot-network.  Copy it to /etc so that
# coreos-copy-firstboot-network can apply it normally.

bootmnt=/mnt/boot_partition
bootdev=/dev/disk/by-label/boot
legacy_dir_name="coreos-firstboot-network"
boot_firstboot_network_dir="${bootmnt}/${legacy_dir_name}"
etc_firstboot_network_dir="/etc/${legacy_dir_name}"

if [ ! -b "${bootdev}" ]; then
    echo "info: boot device ${bootdev} not found; skipping legacy network rescue"
    exit 0
fi

mkdir -p "${bootmnt}"
if ! mount -o ro "${bootdev}" "${bootmnt}"; then
    echo "warning: failed to mount ${bootdev}; skipping legacy network rescue"
    exit 0
fi

if [ -n "$(ls -A "${boot_firstboot_network_dir}" 2>/dev/null)" ]; then
    echo "warning: found legacy firstboot network config in ${boot_firstboot_network_dir}" | tee /dev/kmsg || true
    echo "warning: an older coreos-installer placed network config in /boot instead of the initramfs" | tee /dev/kmsg || true
    echo "warning: rescuing config — copying to ${etc_firstboot_network_dir}" | tee /dev/kmsg || true
    echo "warning: re-install using an updated coreos-installer to avoid this in the future" | tee /dev/kmsg || true
    mkdir -p "${etc_firstboot_network_dir}"
    cp -v "${boot_firstboot_network_dir}"/* "${etc_firstboot_network_dir}/"
else
    echo "info: no legacy network config in ${boot_firstboot_network_dir}; skipping"
fi
