# Display relevant errors then enter emergency shell

# _wait_for_journalctl_to_stop will block until either:
# - no messages have appeared in journalctl for the past 5 seconds
# - 15 seconds have elapsed
_wait_for_journalctl_to_stop() {
    local time_since_last_log=0

    local time_started="$(date '+%s')"
    local now="$(date '+%s')"

    while [ ${time_since_last_log} -lt 5 -a $((now-time_started)) -lt 15 ]; do
        sleep 1

        local last_log_timestamp="$(journalctl -e -n 1 -q -o short-unix | cut -d '.' -f 1)"
        local now="$(date '+%s')"

        local time_since_last_log=$((now-last_log_timestamp))
    done
}

_display_relevant_errors() {
    failed=$(systemctl --failed --no-legend --plain | cut -f 1 -d ' ')
    if [ -n "${failed}" ]; then
        # Something failed, suppress kernel logs so that it's more likely
        # the useful bits from the journal are available.
        dmesg --console-off

        # There's a couple straggler systemd messages. Wait until it's been 5
        # seconds since something was written to the journal.
        _wait_for_journalctl_to_stop

        # Print Ignition logs
        if echo ${failed} | grep -qFe 'ignition-'; then
            cat <<EOF
------
Ignition has failed. Please ensure your config is valid. Note that only
Ignition spec v3.0.0+ configs are accepted.

A CLI validation tool to check this called ignition-validate can be
downloaded from GitHub:
    https://github.com/coreos/ignition/releases
------

EOF
        fi

        # If this is a live boot, check for ENOSPC in initramfs filesystem
        # Try creating a 64 KiB file, in case a small file was deleted on
        # service failure
        # https://github.com/coreos/fedora-coreos-tracker/issues/1055
        if [ -f /etc/coreos-live-initramfs ] && \
            ! dd if=/dev/zero of=/tmp/check-space bs=4K count=16 2>/dev/null; then
            cat <<EOF
------
Ran out of memory when unpacking initrd filesystem.  Ensure your system has
at least 2 GiB RAM if booting with coreos.live.rootfs_url, or 4 GiB otherwise.
------

EOF
            # Don't show logs from failed units, since they'll just be
            # random misleading errors.
        else
            echo "Displaying logs from failed units: ${failed}"
            for unit in ${failed}; do
                # 10 lines should be enough for everyone
                SYSTEMD_COLORS=true journalctl -b --no-pager --no-hostname -u ${unit} -n 10
            done
        fi
    fi
}

# in SE case drop everything before entering shell
if [ -f /run/coreos/secure-execution ]; then
    rm -f /run/ignition.json
    rm -f /usr/lib/ignition/user.ign
    rm -f /usr/lib/coreos/ignition.asc
fi

# Print warnings/informational messages to all configured consoles on the
# machine. Code inspired by https://github.com/dracutdevs/dracut/commit/32f68c1
MESSAGE="$(_display_relevant_errors)"
while read -r _tty rest; do
    echo -e "$MESSAGE" > /dev/"$_tty"
done < /proc/consoles
