install_and_enable_unit() {
    unit="$1"; shift
    target="$1"; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    mkdir -p "$initdir/$systemdsystemunitdir/$target.requires"
    ln_r "../$unit" "$systemdsystemunitdir/$target.requires/$unit"
}

install() {
    inst_multiple truncate

    inst_script "$moddir/is-live-image.sh" \
        "/usr/bin/is-live-image"

    inst_script "$moddir/ostree-cmdline.sh" \
        "/usr/sbin/ostree-cmdline"

    inst_simple "$moddir/live-generator" \
        "$systemdutildir/system-generators/live-generator"

    inst_simple "$moddir/coreos-live-unmount-tmpfs-var.sh" \
        "/usr/sbin/coreos-live-unmount-tmpfs-var"

    install_and_enable_unit "coreos-live-unmount-tmpfs-var.service" \
        "initrd-switch-root.target"

    install_and_enable_unit "coreos-live-clear-sssd-cache.service" \
        "ignition-complete.target"

    install_and_enable_unit "coreos-live-persist-osmet.service" \
        "default.target"

    inst_simple "$moddir/coreos-liveiso-network-kargs.sh" \
        "/usr/sbin/coreos-liveiso-network-kargs"

    inst_simple "$moddir/coreos-liveiso-network-kargs.service" \
        "$systemdsystemunitdir/coreos-liveiso-network-kargs.service"

    inst_simple "$moddir/coreos-liveiso-reconfigure-nm-wait-online.service" \
        "$systemdsystemunitdir/coreos-liveiso-reconfigure-nm-wait-online.service"
}
