#!/bin/bash
set -xeuo pipefail

# Setup configuration for a single NIC with two different ways:
# - kargs provide static network config for ens5 and also coreos.force_persist_ip
# - ignition provides dhcp network config for ens5
# Expected result:
# - with coreos.force_persist_ip ip=kargs win, verify that 
#   ens5 has the static IP address via kargs

# https://bugzilla.redhat.com/show_bug.cgi?id=1958930#c29
# These tests fail on aarch64. Limit to x86_64 for now:
# 	- https://github.com/coreos/fedora-coreos-tracker/issues/1060
# kola: { "platforms": "qemu", "additionalNics": 1, "appendKernelArgs": "ip=10.10.10.10::10.10.10.1:255.255.255.0:myhostname:ens5:none:8.8.8.8 coreos.force_persist_ip", "architectures": "x86_64"}

. $KOLA_EXT_DATA/commonlib.sh

# Verify ens5 get staic ip via kargs
nic_name="ens5"
nic_ip=$(get_ipv4_for_nic ${nic_name})
if [ ${nic_ip} != "10.10.10.10" ]; then
    fatal "Error: get ${nic_name} ip = ${nic_ip}, expected is 10.10.10.10"
fi
ok "get ${nic_name} ip is 10.10.10.10"

syscon="/etc/NetworkManager/system-connections"
if [ ! -f "${syscon}/${nic_name}.nmconnection" ]; then
    fatal "Error: can not find ${syscon}/${nic_name}.nmconnection"
fi
ok "find ${syscon}/${nic_name}.nmconnection"

# Verify logs
if ! journalctl -b 0 -u coreos-teardown-initramfs | \
     grep -q "info: coreos.force_persist_ip detected: will force network config propagation"; then
  fatal "Error: force network config propagation not work"
fi
ok "force network config propagation"
