#!/bin/bash
# If the user specified a persistent /var, ideally it'd just be mounted
# overtop of our tmpfs /var and everything would be fine.  That works
# fine in the initramfs, where ignition-mount handles the mounting.
# But in the real root, the user's mount unit is ignored by systemd,
# since there's already a filesystem mounted on /var.  To fix this, we
# notice that the user wants to mount /var, and unmount our tmpfs /var
# before switching roots.

set -euo pipefail

should_unmount() {
    # Did the user specify a mount unit for /var?
    if [ -e /sysroot/etc/systemd/system/var.mount ]; then
        return 0
    fi

    # Is there an fstab entry for /var?
    if [ -e /sysroot/etc/fstab ]; then
        # Uncommented entry with mountpoint on /var, without noauto in options
        result=$(awk '(! /^\s*#/) && ($2 == "/var") && ($4 !~ /noauto/) {print "found"}' /sysroot/etc/fstab)
        if [ -n "$result" ]; then
            return 0
        fi
    fi

    return 1
}

if should_unmount; then
    echo "Unmounting /sysroot/var"
    umount /sysroot/var
fi
