#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

depends() {
    echo systemd
}

install_and_enable_unit() {
    unit="$1"; shift
    target="$1"; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    # note we `|| exit 1` here so we error out if e.g. the units are missing
    # see https://github.com/coreos/fedora-coreos-config/issues/799
    systemctl -q --root="$initdir" add-requires "$target" "$unit" || exit 1
}

install() {
    inst_script "$moddir/secex-init" \
        "/secex-init"

    inst_simple "$moddir/01-secex.ign" \
        "/usr/lib/coreos/01-secex.ign"

    inst_script "$moddir/coreos-secex-keyring.sh" \
        "/usr/sbin/coreos-secex-keyring"

    inst_script "$moddir/coreos-secex-config-luks.sh" \
        "/usr/sbin/coreos-secex-config-luks"

    inst_simple "$moddir/coreos-secex-generator" \
        "$systemdutildir/system-generators/coreos-secex-generator"

    install_and_enable_unit "coreos-secex-keyring.service" \
        "initrd.target"
    install_and_enable_unit "coreos-secex-config-luks.service" \
        "ignition-complete.target"
}
