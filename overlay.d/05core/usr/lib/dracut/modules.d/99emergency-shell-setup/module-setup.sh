#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

install_unit_wants() {
    local unit="$1"; shift
    local target="$1"; shift
    local instantiated="${1:-$unit}"; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    # note we `|| exit 1` here so we error out if e.g. the units are missing
    # see https://github.com/coreos/fedora-coreos-config/issues/799
    systemctl -q --root="$initdir" add-wants "$target" "$instantiated" || exit 1
}

install() {
    inst_multiple \
        cut \
        date \
        dd

    inst_hook emergency 99 "${moddir}/emergency-shell.sh"

    inst_script "$moddir/ignition-virtio-dump-journal.sh" "/usr/bin/ignition-virtio-dump-journal"
    install_unit_wants ignition-virtio-dump-journal.service emergency.target
}
