install_and_enable_unit() {
    unit="$1"; shift
    target="$1"; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    # note we `|| exit 1` here so we error out if e.g. the units are missing
    # see https://github.com/coreos/fedora-coreos-config/issues/799
    systemctl -q --root="$initdir" add-requires "$target" "$unit" || exit 1
}

install() {
    inst_simple readlink

    inst_simple "$moddir/coreos-enable-iptables-legacy.sh" \
        "/usr/sbin/coreos-enable-iptables-legacy"
    install_and_enable_unit "coreos-enable-iptables-legacy.service" \
        "initrd.target"
}
