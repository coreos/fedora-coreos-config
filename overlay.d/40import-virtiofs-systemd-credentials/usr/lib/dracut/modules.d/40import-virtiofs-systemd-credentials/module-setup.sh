#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Dracut module: import-virtiofs-systemd-credentials
#
# Imports systemd credentials from a virtiofs share tagged
# "io.systemd.credentials" into /run/credentials/@system/.
# This runs in the initramfs so that systemd credentials are available
# to generators in the real root (e.g. systemd-debug-generator for
# systemd.extra-unit.* and systemd.unit-dropin.*) and early services
# (e.g. systemd-tmpfiles-setup for tmpfiles.extra).
#
# This provides a cross-architecture alternative to SMBIOS OEM strings
# and fw_cfg for passing systemd credentials into VMs. Unlike those
# mechanisms, virtiofs works on all architectures including s390x and
# ppc64le.
#
# See https://systemd.io/CREDENTIALS/
# See https://github.com/systemd/systemd/issues/29175

check() {
    # Don't include in kdump initramfs
    if [[ $IN_KDUMP == 1 ]]; then
        return 1
    fi
    return 0
}

depends() {
    echo systemd
}

installkernel() {
    instmods -c virtiofs
}

install_and_enable_unit() {
    local unit="$1"; shift
    local target="$1"; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    systemctl -q --root="$initdir" add-requires "$target" "$unit" || exit 1
}

install() {
    inst_script "$moddir/import-virtiofs-systemd-credentials.sh" \
        "/usr/libexec/import-virtiofs-systemd-credentials.sh"

    install_and_enable_unit import-virtiofs-systemd-credentials.service initrd.target
}
