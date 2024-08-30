#!/bin/bash
# With live PXE there's no ostree= argument on the kernel command line, so
# we need to find the tree path and pass it to ostree-prepare-root.  But
# ostree-prepare-root only knows how to read the path from
# /proc/cmdline, so we need to synthesize the proper karg and bind-mount
# it over /proc/cmdline.
# https://github.com/ostreedev/ostree/issues/1920

set -euo pipefail

case "${1:-unset}" in
    start)
        treepath="$(echo /sysroot/ostree/boot.1/*/*/0)"
        # ostree-prepare-root requires /etc and /var to be writeable for composeFS
        # which cannot happen in the live ISO. Disable composeFS there
        # https://github.com/coreos/fedora-coreos-config/pull/3009#issuecomment-2235923719
        echo "$(cat /proc/cmdline) ostree=${treepath#/sysroot} ostree.prepare-root.composefs=0" > /tmp/cmdline
        mount --bind /tmp/cmdline /proc/cmdline
        ;;
    stop)
        umount -l /proc/cmdline
        rm /tmp/cmdline
        ;;
    *)
        echo "Usage: $0 {start|stop}" >&2
        exit 1
        ;;
esac
