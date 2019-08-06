# For now we are using kmsg [1] for multiplexing output to
# multiple console devices during early boot. We need to also tell
# the kernel not to ratelimit kmsg during the initramfs.
#
# We do not want to use kmsg in the future as there may be sensitive
# ignition data that leaks to non-root users (by reading the kernel
# ring buffer using `dmesg`). In the future we will rely on kernel
# console multiplexing [2] for this and will not use kmsg.
#
# [1] https://github.com/coreos/ignition-dracut/blob/26f2396b116286dcb46644dc157e4211aea3aba5/dracut/99journald-conf/00-journal-log-forwarding.conf#L2
# [2] https://github.com/coreos/fedora-coreos-tracker/issues/136

# See also 10-coreos-ratelimit-kmsg.conf, which turns ratelimiting back *on*
# in the real root.

check() {
    return 0
}

install() {
    mkdir -p "$initdir/etc/sysctl.d"
    echo "kernel.printk_devkmsg = on" > "$initdir/etc/sysctl.d/10-dont-ratelimit-kmsg.conf"
}
