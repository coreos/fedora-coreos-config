install_and_enable_unit() {
    unit="$1"; shift
    target="$1"; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    mkdir -p "$initdir/$systemdsystemunitdir/$target.requires"
    ln_r "../$unit" "$systemdsystemunitdir/$target.requires/$unit"
}

install() {
    inst_simple "$moddir/coreos-copy-firstboot-network.sh" \
        "/usr/sbin/coreos-copy-firstboot-network"
    # Only run this when ignition runs and only when the system
    # has disks. ignition-diskful.target should suffice.
    install_and_enable_unit "coreos-copy-firstboot-network.service" \
        "ignition-diskful.target"

    # Dropin with firstboot network configuration kargs, applied via
    # Afterburn.
    inst_simple "$moddir/50-afterburn-network-kargs-default.conf" \
        "/usr/lib/systemd/system/afterburn-network-kargs.service.d/50-afterburn-network-kargs-default.conf"

}
