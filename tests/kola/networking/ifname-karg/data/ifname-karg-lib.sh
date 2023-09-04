# This is a library created for our ifname-karg tests

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# check IP for given NIC name
check_ip() {
    # User provides the NIC name.
    local nic_name=$1
    # The expected IP is the first one in the range given out by QEMU
    # user mode networking: https://www.qemu.org/docs/master/system/devices/net.html#using-the-user-mode-network-stack
    local expected_ip="10.0.2.15"
    # Verify the given nic name has the expected IP.
    local nic_ip=$(get_ipv4_for_nic ${nic_name})
    if [ "${nic_ip}" != "${expected_ip}" ]; then
        fatal "Error: get ${nic_name} ip = ${nic_ip}, expected is ${expected_ip}"
    fi
    ok "get ${nic_name} ip is ${expected_ip}"
}

# simple file existence check
check_file_exists() {
    local file=$1
    if [ ! -f $file ]; then
        fatal "expected file ${file} doesn't exist on disk"
    fi
    ok "expected file ${file} exists on disk"
}

# simple file non-existence check
check_file_not_exists() {
    local file=$1
    if [ -f $file ]; then
        fatal "expected file ${file} to not exist on disk"
    fi
    ok "file ${file} does not exist on disk"
}
