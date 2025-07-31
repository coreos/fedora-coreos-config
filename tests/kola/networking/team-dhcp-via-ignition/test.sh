#!/bin/bash
## kola:
##   # additionalNics is only supported on QEMU
##   platforms: qemu
##   # Add 2 NIC for this test
##   additionalNics: 2
##   # We use net.ifnames=0 to disable consistent network naming here because on
##   # different firmwares (BIOS vs UEFI) the NIC names are different.
##   # See https://github.com/coreos/fedora-coreos-tracker/issues/1060
##   appendKernelArgs: "net.ifnames=0"
##   description: Verify team networking works via Ignition config.

# The Ignition config refers to
# https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-network-configuration/

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

check_ip() {
    team="$1"

    # Verify team0 gets dhcp according to config.bu
    nic_ip=$(get_ipv4_for_nic ${team})
    if [ "${nic_ip}" != "10.0.2.31" ]; then
        # On s390x, devices use the CCW bus instead of PCI, which may cause them to appear in the wrong order
        # https://github.com/coreos/fedora-coreos-tracker/issues/1992
        if [ $(uname -m) == s390x ] && [ "${nic_ip}" == "10.0.2.32" ]; then
            eval $(udevadm info --query=property /sys/class/net/eth1 | grep ID_NET_NAME_PATH)
            if [[ "${ID_NET_NAME_PATH}" != "enc3" ]]; then
                echo "Warn: CCW bus devices's order is wrong: eth0 altname is ${ID_NET_NAME_PATH}"
            else
                fatal "Error: get ${team} ip = ${nic_ip}, expected is 10.0.2.31. eth0 altname is ${ID_NET_NAME_PATH}"
            fi
        else
            fatal "Error: get ${team} ip = ${nic_ip}, expected is 10.0.2.31"
        fi
    fi
}

main() {
    team="team0"

    check_ip "${team}"

    expected_state="setup:
  runner: activebackup
ports:
  eth1
    link watches:
      link summary: up
      instance[link_watch_0]:
        name: ethtool
        link: up
        down count: 0
  eth2
    link watches:
      link summary: up
      instance[link_watch_0]:
        name: ethtool
        link: up
        down count: 0
runner:
  active port: eth1"

    state=`teamdctl team0 state`
    if ! diff -u <(echo "$expected_state") <(echo "$state"); then
        fatal "Error: the expected team0 network is not the same as expected"
    fi

    ok "networking ${team} tests"
}

# See https://issues.redhat.com/browse/NMT-1056
if match_maj_ver "10"; then
    ok "skip team networking tests"
    exit 0
fi

main
