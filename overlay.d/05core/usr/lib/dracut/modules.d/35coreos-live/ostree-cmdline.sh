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
        echo "$(cat /proc/cmdline) ostree=${treepath#/sysroot}" > /tmp/cmdline
        mount --bind /tmp/cmdline /proc/cmdline
        # prepare-root.conf wants to turn on sysroot.readonly and composefs
        # We can't use composefs in the live ISO because ostree-prepare-root requires /etc and /var to be writeable.
        # https://github.com/coreos/fedora-coreos-config/pull/3009#issuecomment-2235923719
        # The sysroot.readonly bit would be fine nowadays (since
        # https://github.com/ostreedev/ostree/pull/3316) but it also
        # unnecessarily complicates the mount tree given that we're read-only
        # anyway but ostree-prepare-root still wants to e.g. remount `/etc`.
        # Could tweak the logic there, but for now just mask the file entirely.
        # We have our own /var and /etc transient mounts.
        mount --bind /dev/null /usr/lib/ostree/prepare-root.conf
        ;;
    stop)
        umount -l /usr/lib/ostree/prepare-root.conf
        umount -l /proc/cmdline
        rm /tmp/cmdline
        ;;
    *)
        echo "Usage: $0 {start|stop}" >&2
        exit 1
        ;;
esac
