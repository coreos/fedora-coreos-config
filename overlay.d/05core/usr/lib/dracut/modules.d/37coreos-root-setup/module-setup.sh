#!/bin/bash

check() {
    return 0
}

depends() {
    return 0
}

install() {
    local service=coreos-root-setup.service

    inst_script "$moddir/coreos-root-setup.sh" /usr/libexec/coreos-root-setup

    inst "$moddir/bootc-initramfs-setup" /usr/lib/bootc/initramfs-setup

    inst_simple "$moddir/${service}" "${systemdsystemunitdir}/${service}"
    mkdir -p "${initdir}${systemdsystemconfdir}/initrd-root-fs.target.wants"
    ln_r "${systemdsystemunitdir}/${service}" \
        "${systemdsystemconfdir}/initrd-root-fs.target.wants/${service}"
}
