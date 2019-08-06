#!/bin/bash
set -euo pipefail

# Clean up the interfaces set up in the initramfs
# This mimics the behaviour of dracut's ifdown() in net-lib.sh
# This script should be considered temporary. We eventually
# want to move to NetworkManager based dracut modules. See:
# https://github.com/dracutdevs/dracut/tree/master/modules.d/35network-manager
if ! [ -z "$(ls /sys/class/net)" ]; then
    for f in /sys/class/net/*; do
        interface=$(basename "$f")
        ip link set $interface down
        ip addr flush dev $interface
        rm -f -- /tmp/net.$interface.did-setup
    done
fi
