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

. $KOLA_EXT_DATA/commonlib.sh

team="team0"

# Verify team0 gets dhcp according to config.bu
nic_ip=$(get_ipv4_for_nic ${team})
if [ "${nic_ip}" != "10.0.2.31" ]; then
    fatal "Error: get ${team} ip = ${nic_ip}, expected is 10.0.2.31"
fi

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
