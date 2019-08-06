#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

depends() {
    echo ignition
}

install_ignition_unit() {
    unit=$1; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    ln_r "../$unit" "$systemdsystemunitdir/ignition-complete.target.requires/$unit"
}

install() {
    inst_multiple \
        systemd-sysusers \
        systemd-tmpfiles

    mkdir -p "$initdir/$systemdsystemunitdir/ignition-complete.target.requires"

    install_ignition_unit coreos-mount-var.service
    inst_script "$moddir/coreos-mount-var.sh" \
        "/usr/sbin/coreos-mount-var"

    install_ignition_unit coreos-populate-var.service
    inst_script "$moddir/coreos-populate-var.sh" \
        "/usr/sbin/coreos-populate-var"
}
