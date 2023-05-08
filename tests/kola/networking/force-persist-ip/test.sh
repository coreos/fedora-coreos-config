#!/bin/bash
## kola:
##   # additionalNics is only supported on QEMU
##   platforms: qemu
##   # Add 1 NIC for this test
##   additionalNics: 1
##   # The functionality we're testing here and the configuration for the NIC
##   # We use net.ifnames=0 to disable consistent network naming here because on
##   # different firmwares (BIOS vs UEFI) the NIC names are different.
##   # See https://github.com/coreos/fedora-coreos-tracker/issues/1060
##   appendKernelArgs: "ip=10.10.10.10::10.10.10.1:255.255.255.0:myhostname:eth1:none:8.8.8.8 net.ifnames=0 coreos.force_persist_ip"
##   # appendKernelArgs doesn't work on s390x
##   # https://github.com/coreos/coreos-assembler/issues/2776
##   architectures: "!s390x"
##   description: Verify that coreos.force_persist_ip will force propagating 
##     kernel argument based networking configuration into the real root.

# Setup configuration for a single NIC with two different ways:
# - kargs provide static network config for eth1 and also coreos.force_persist_ip
# - Ignition provides dhcp network config for eth1
# Expected result:
# - with coreos.force_persist_ip ip=kargs win, verify that
#   eth1 has the static IP address via kargs
# https://bugzilla.redhat.com/show_bug.cgi?id=1958930#c29

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# Verify eth1 gets staic ip via kargs
nic_name="eth1"
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
