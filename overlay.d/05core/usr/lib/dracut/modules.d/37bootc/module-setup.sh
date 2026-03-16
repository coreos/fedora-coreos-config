#!/bin/bash
installkernel() {
    instmods erofs overlay
}
check() {
    # We are never installed by default; see 10-bootc-base.conf
    # for how base images can opt in.
    return 0
}
depends() {
    return 0
}
install() {
    local service=bootc-root-setup.service
    inst_binary "$moddir/bootc-initramfs-setup" /usr/lib/bootc/initramfs-setup
    inst_simple "${systemdsystemunitdir}/${service}"
    mkdir -p "${initdir}${systemdsystemconfdir}/initrd-root-fs.target.wants"
    ln_r "${systemdsystemunitdir}/${service}" \
        "${systemdsystemconfdir}/initrd-root-fs.target.wants/${service}"
}
