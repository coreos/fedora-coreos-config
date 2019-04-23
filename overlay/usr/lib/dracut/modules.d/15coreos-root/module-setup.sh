# Populate /root with default bash configs. See:
# https://bugzilla.redhat.com/show_bug.cgi?id=1193590

depends() {
    echo ignition
}

check() {
    return 0
}

install() {
    local unit=coreos-root-bash.service
    mkdir -p "$initdir/$systemdsystemunitdir/ignition-complete.target.requires"
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    ln_r "../$unit" "$systemdsystemunitdir/ignition-complete.target.requires/$unit"
}
