#!/bin/bash
## kola:
##   # additionalNics is only supported on QEMU
##   platforms: qemu
##   # Add 1 additional NIC for this test
##   additionalNics: 1
##   # Set the kernel arguments so that we can set the configuration for the NIC.
##   # We use net.ifnames=0 to disable consistent network naming here because on
##   # different firmwares (BIOS vs UEFI) the NIC names are different.
##   # See https://github.com/coreos/fedora-coreos-tracker/issues/1060
##   appendKernelArgs: "ip=10.10.10.10::10.10.10.1:255.255.255.0:myhostname:eth1:none:8.8.8.8 net.ifnames=0"
##   # appendKernelArgs doesn't work on s390x so skip there
##   # https://github.com/coreos/coreos-assembler/issues/2776
##   architectures: "!s390x"
##   description: Verify that networking configuration is propagated 
##     via Ignition by default.

# Setup configuration for a single NIC with two different ways:
# - kargs provide static network config for eth1 without coreos.force_persist_ip
# - Ignition provides dhcp network config for eth1
# Expected result:
# - without coreos.force_persist_ip Ignition networking
#   configuration wins, verify that eth1 gets ip via dhcp
# See https://bugzilla.redhat.com/show_bug.cgi?id=1958930#c29

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# Verify eth1 gets ip address via dhcp
nic_name="eth1"
nic_ip=$(get_ipv4_for_nic ${nic_name})
if [ ${nic_ip} != "10.0.2.31" ]; then
    fatal "Error: get ${nic_name} ip = ${nic_ip}, expected is 10.0.2.31"
fi
ok "get ${nic_name} ip is 10.0.2.31"

syscon="/etc/NetworkManager/system-connections"
if [ ! -f "${syscon}/${nic_name}.nmconnection" ]; then
    fatal "Error: can not find ${syscon}/${nic_name}.nmconnection"
fi
ok "find ${syscon}/${nic_name}.nmconnection"
