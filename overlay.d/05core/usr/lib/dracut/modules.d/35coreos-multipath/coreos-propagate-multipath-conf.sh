#!/bin/bash
set -euo pipefail

# Persist automatic multipath configuration, if any.
# When booting with `rd.multipath=default`, the default multipath
# configuration is written. We need to ensure that the multipath configuration
# is persisted to the final target.

if [ ! -f /sysroot/etc/multipath.conf ] && [ -f /etc/multipath.conf ]; then
    echo "info: propagating automatic multipath configuration"
    cp -v /etc/multipath.conf /sysroot/etc/
    mkdir -p /sysroot/etc/multipath/multipath.conf.d
    coreos-relabel /etc/multipath.conf
    coreos-relabel /etc/multipath/multipath.conf.d
else
    echo "info: no initramfs automatic multipath configuration to propagate"
fi
