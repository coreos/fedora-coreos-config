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

    install_ignition_unit ignition-ostree-mount-var.service
    inst_script "$moddir/ignition-ostree-mount-var.sh" \
        "/usr/sbin/ignition-ostree-mount-var"

    install_ignition_unit ignition-ostree-populate-var.service
    inst_script "$moddir/ignition-ostree-populate-var.sh" \
        "/usr/sbin/ignition-ostree-populate-var"
}
