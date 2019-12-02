#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

depends() {
    echo ignition
}

install_ignition_unit() {
    local unit=$1; shift
    local target=${1:-complete}
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    local targetpath="$systemdsystemunitdir/ignition-${target}.target.requires/"
    mkdir -p "${initdir}/${targetpath}"
    ln_r "../$unit" "${targetpath}/${unit}"
}

install() {
    inst_multiple \
        realpath \
        systemd-sysusers \
        systemd-tmpfiles \
        sort \
        uniq

    # growpart deps
    inst_multiple sfdisk awk realpath basename dirname sfdisk xfs_growfs resize2fs growpart touch

    for x in mount populate; do
        install_ignition_unit ignition-ostree-${x}-var.service
        inst_script "$moddir/ignition-ostree-${x}-var.sh" "/usr/sbin/ignition-ostree-${x}-var"
    done

    install_ignition_unit ignition-ostree-mount-firstboot-sysroot.service
    install_ignition_unit ignition-ostree-mount-subsequent-sysroot.service subsequent
    inst_script "$moddir/ignition-ostree-mount-sysroot.sh" \
        "/usr/sbin/ignition-ostree-mount-sysroot"

    install_ignition_unit ignition-ostree-growfs.service
    inst_script "$moddir/coreos-growpart" /usr/libexec/coreos-growpart
}
