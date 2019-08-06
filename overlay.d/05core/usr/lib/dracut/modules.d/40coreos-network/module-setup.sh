#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

depends() {
    echo ignition
}

install() {
    local unit=coreos-teardown-initramfs-network.service
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    inst_script "$moddir/coreos-teardown-initramfs-network.sh" \
        "/usr/sbin/coreos-teardown-initramfs-network"
}
