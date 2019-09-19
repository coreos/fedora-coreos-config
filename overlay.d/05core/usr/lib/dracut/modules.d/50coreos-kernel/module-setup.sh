install_unit() {
    unit="$1"; shift
    target="$1"; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    mkdir -p "$initdir/$systemdsystemunitdir/$target.requires"
    ln_r "../$unit" "$systemdsystemunitdir/$target.requires/$unit"
}

install() {
    inst_multiple \
        false

    install_unit "coreos-check-kernel.service" "sysinit.target"
}
