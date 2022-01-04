#!/bin/bash
set -xeuo pipefail

# Setup configuration for a single NIC with two different ways:
# - kargs provide static network config for ens5 without coreos.force_persist_ip
# - ignition provides dhcp network config for ens5
# Expected result:
# - without coreos.force_persist_ip Ignition networking 
#   configuration wins, verify that ens5 gets ip via dhcp

# https://bugzilla.redhat.com/show_bug.cgi?id=1958930#c29
# kola: { "platforms": "qemu", "additionalNics": 1, "appendKernelArgs": "ip=10.10.10.10::10.10.10.1:255.255.255.0:myhostname:ens5:none:8.8.8.8"}

. $KOLA_EXT_DATA/commonlib.sh

# Verify ens5 get ip address via dhcp
nic_name="ens5"
nic_ip=""
get_ip_for_nic ${nic_name}
if [ ${nic_ip} != "10.0.2.31" ]; then
    fatal "Error: get ${nic_name} ip = ${nic_ip}, expected is 10.0.2.31"
fi
ok "get ${nic_name} ip is 10.0.2.31"

syscon="/etc/NetworkManager/system-connections"
if [ ! -f "${syscon}/${nic_name}.nmconnection" ]; then
    fatal "Error: can not find ${syscon}/${nic_name}.nmconnection"
fi
ok "find ${syscon}/${nic_name}.nmconnection"
