#!/bin/bash

have_karg() {
    local arg="$1"
    IFS=" " read -r -a cmdline <<< "$(</proc/cmdline)"
    local i
    for i in "${cmdline[@]}"; do
        if [[ "$i" =~ "$arg=" ]]; then
            return 0
        fi
    done
    return 1
}

if have_karg composefs; then
    /usr/lib/bootc/initramfs-setup setup-root
elif have_karg ostree; then
    /usr/lib/ostree/ostree-prepare-root /sysroot
else
    echo "Neither ostree nor composefs found in cmdline"
    exit 1
fi
