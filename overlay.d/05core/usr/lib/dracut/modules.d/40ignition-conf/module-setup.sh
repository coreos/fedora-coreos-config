#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

depends() {
    echo ignition
}

install() {
    mkdir -p "$initdir/usr/lib/ignition/base.d"
    inst "$moddir/00-core.ign" \
        "/usr/lib/ignition/base.d/00-core.ign"
}
