install_unit() {
    unit="$1"; shift
    target="$1"; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    systemctl -q --root="$initdir" add-requires "$target" "$unit"
}

install() {
    inst_multiple \
        false

    install_unit "coreos-check-kernel.service" "sysinit.target"
}
