install() {
    inst_script "$moddir/is-live-image.sh" \
        "/usr/bin/is-live-image"

    inst_script "$moddir/ostree-cmdline.sh" \
        "/usr/sbin/ostree-cmdline"

    inst_simple "$moddir/live-generator" \
        "$systemdutildir/system-generators/live-generator"

    inst_simple "$moddir/coreos-populate-writable.service" \
        "$systemdsystemunitdir/coreos-populate-writable.service"

    inst_simple "$moddir/writable.mount" \
        "$systemdsystemunitdir/writable.mount"
}
