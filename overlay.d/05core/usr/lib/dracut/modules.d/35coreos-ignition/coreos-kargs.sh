#!/bin/bash
set -euo pipefail

fail_live() {
    echo "Need to $1, but cannot change kernel arguments in live system." >&2
    exit 1
}

if is-live-image; then
    # In the live case, we can't actually change anything.  Check the
    # arguments and succeed anyway if there's nothing we need to do.

    # add leading and trailing whitespace to allow for easy matching
    kernelopts=" $(cat /proc/cmdline) "

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --should-exist)
            arg="$2"
            if [[ ! "${kernelopts}" =~ " ${arg} " ]]; then
                fail_live "add kernel argument '${arg}'"
            fi
            shift 2
            ;;
        --should-not-exist)
            arg="$2"
            if [[ "${kernelopts}" =~ " ${arg} " ]]; then
                fail_live "remove kernel argument '${arg}'"
            fi
            shift 2
            ;;
        *)
            echo "Unknown option" >&2
            exit 1
            ;;
        esac
    done
else
    /usr/bin/rdcore kargs --boot-device /dev/disk/by-label/boot --create-if-changed /run/coreos-kargs-reboot "$@"
fi
