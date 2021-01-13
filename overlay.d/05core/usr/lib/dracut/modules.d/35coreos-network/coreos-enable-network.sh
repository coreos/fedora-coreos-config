#!/bin/bash
set -euo pipefail

set +euo pipefail
. /usr/lib/dracut-lib.sh
set -euo pipefail

initramfs_network_dir="/run/NetworkManager/system-connections/"

dracut_func() {
    # dracut is not friendly to set -eu
    set +euo pipefail
    "$@"; local rc=$?
    set -euo pipefail
    return $rc
}

# If networking hasn't been requested yet, request it.
if ! dracut_func getargbool 0 'rd.neednet'; then
    echo "rd.neednet=1" > /etc/cmdline.d/40-coreos-neednet.conf

    # Hack: if there's already network configs there, then preserve and restore
    # it. All we want to do here is make sure that NM will be started during
    # initqueue; we don't want to affect the actual configs it uses, which
    # might've come from dracut-cmdline or coreos-copy-firstboot-network.
    if [ -n "$(ls -A ${initramfs_network_dir} 2>/dev/null)" ]; then
        mv "${initramfs_network_dir}" "${initramfs_network_dir}.bak"
    fi

    # Hack: we need to rerun the NM cmdline hook because we run after
    # dracut-cmdline.service because we need udev. We should be able to move
    # away from this once we run NM as a systemd unit. See also:
    # https://github.com/coreos/fedora-coreos-config/pull/346#discussion_r409843428
    set +euo pipefail
    . /usr/lib/dracut/hooks/cmdline/99-nm-config.sh
    set -euo pipefail

    if [ -d "${initramfs_network_dir}.bak" ]; then
        rm -rf "${initramfs_network_dir}"
        mv "${initramfs_network_dir}".bak "${initramfs_network_dir}"
    fi
fi
