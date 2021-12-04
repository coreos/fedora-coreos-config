#!/bin/bash
set -euo pipefail

if is-live-image; then
    /usr/bin/rdcore kargs --current --create-if-changed /run/coreos-kargs-changed "$@"
    if [ -e /run/coreos-kargs-changed ]; then
        echo "Need to modify kernel arguments, but cannot affect live system." >&2
        exit 1
    fi
else
    /usr/bin/rdcore kargs --boot-device /dev/disk/by-label/boot --create-if-changed /run/coreos-kargs-reboot "$@"
fi
