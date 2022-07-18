#!/bin/bash
set -euo pipefail

# Persist automatic multipath configuration, if any.
# When booting with `rd.multipath=default`, the default multipath
# configuration is written. We need to ensure that the multipath configuration
# is persisted to the rootfs.

if [ ! -f /etc/multipath.conf ]; then
    echo "info: initrd file /etc/multipath.conf does not exist"
    echo "info: no initrd multipath configuration to propagate"
    exit 0
fi

if [ -f /sysroot/etc/multipath.conf ]; then
    echo "info: real root file /etc/multipath.conf exists"
    echo "info: not propagating initrd multipath configuration"
    exit 0
fi

echo "info: propagating initrd multipath configuration"
cp -v /etc/multipath.conf /sysroot/etc/
coreos-relabel /etc/multipath.conf
