#!/bin/bash
# Configuration for systemd in the initramfs.
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

depends() {
    echo systemd
}

install() {
    inst_simple "$moddir/10-coreos-nocolor.conf" \
        "/etc/systemd/system.conf.d/00-coreos-nocolor.conf"
    inst_simple "$moddir/00-journal-log-forwarding.conf" \
        "/etc/systemd/journald.conf.d/00-journal-log-forwarding.conf"
}
