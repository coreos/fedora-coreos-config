#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

depends() {
       echo systemd
}

install_and_enable_unit() {
       local unit="$1"; shift
       local target="$1"; shift
       inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
       # note we `|| exit 1` here so we error out if e.g. the units are missing
       # see https://github.com/coreos/fedora-coreos-config/issues/799
       systemctl -q --root="$initdir" add-requires "$target" "$unit" || exit 1
}

install() {
    inst_multiple chzdev lszdev awk

    install_and_enable_unit "ibm-znet-rules.service" \
                            "ignition-complete.target"

    inst_script "$moddir/ibm-znet-rules.sh" \
                "/usr/sbin/ibm-znet-rules"
}
