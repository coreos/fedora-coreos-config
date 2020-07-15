#!/usr/bin/bash

# For a description of how this is used see coreos-liveiso-network-kargs.service

# Note that this script is only used on RHCOS now. We should be able to remove
# it once RHCOS moves to spec3. On FCOS/spec3, this is replaced by the
# conditional networking work:
# https://github.com/coreos/fedora-coreos-config/pull/426

# Load the dracut library for getarg
source /usr/lib/dracut-lib.sh

main() {

    # If we're running this script we already know we need networking
    # (determined by conditionals in the systemd unit).
    echo 'info: Requesting networking in the initramfs'
    echo 'rd.neednet=1' > /etc/cmdline.d/10-coreos-liveiso-network-kargs.conf

    # If there is not already a ip= CLI arg use ip=dhcp,dhcp6 as default.
    if ! getarg 'ip' &>/dev/null; then
        echo 'info: using ip=dhcp,dhcp6 default networking configuration'
        echo 'ip=dhcp,dhcp6' >> /etc/cmdline.d/10-coreos-liveiso-network-kargs.conf
    else
        echo 'info: using already set karg ip= information'
    fi
}

main
