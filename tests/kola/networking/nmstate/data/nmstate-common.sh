# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

main() {
    nmstatectl show
    journalctl -u nmstate
    
    local prefix="first boot"
    if [ "${AUTOPKGTEST_REBOOT_MARK:-}" == rebooted ]; then
        prefix="second boot"
    fi
    
    if ! nmcli c show br-ex; then
        fatal "${prefix}: bridge not configured"
    fi

    if ! ls /etc/nmstate/*applied; then
        fatal "${prefix}: nmstate yamls files not marked as applied"    
    fi

    if [ "${AUTOPKGTEST_REBOOT_MARK:-}" == "" ]; then
        /tmp/autopkgtest-reboot rebooted
    fi
}
