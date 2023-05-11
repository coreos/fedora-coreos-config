#!/bin/bash
## kola:
##   # additionalNics is only supported on QEMU
##   platforms: qemu
##   # Add 2 NIC for this test
##   additionalNics: 2
##   # We use net.ifnames=0 to disable consistent network naming here because on
##   # different firmwares (BIOS vs UEFI) the NIC names are different.
##   # See https://github.com/coreos/fedora-coreos-tracker/issues/1060
##   appendKernelArgs: net.ifnames=0
##   description: Verify that configure MTU on a VLAN subinterface for 
##     the bond via Ignition works.
#
# Set MTU on a VLAN subinterface for the bond using Ignition config and check
# - verify MTU on the bond matches config
# - verify MTU on the VLAN subinterface for the bond matches config
# - verify ip address on the VLAN subinterface for the bond matches config
#
# The Ignition config is generated using nm-initrd-generator according to
# https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-network-configuration/
# kargs="bond=bond0:eth1,eth2:mode=active-backup,miimon=100:9000 \
#        ip=10.10.10.10::10.10.10.1:255.255.255.0:staticvlanbond:bond0.100:none:9000: \
#        vlan=bond0.100:bond0"
# $/usr/libexec/nm-initrd-generator -s -- $kargs
#
# Using kernel args to `configure MTU on a VLAN subinterface for the bond` refer to
# https://github.com/coreos/fedora-coreos-config/pull/1401

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

bond="bond0"
vlan="bond0.100"
for interface in $bond $vlan
do
    mtu=""
    # MTU is changed to 9000 according to config.bu
    mtu=$(nmcli -g 802-3-ethernet.mtu connection show ${interface})
    if [ "${mtu}" != "9000" ]; then
        fatal "Error: get ${interface} mtu = ${mtu}, expected is 9000"
    fi
    ok "${interface} mtu is correct"
done

# Verify "bond0.100" gets ip address 10.10.10.10 according to config.bu
nic_ip=$(get_ipv4_for_nic ${vlan})
if [ "${nic_ip}" != "10.10.10.10" ]; then
    fatal "Error: get ${vlan} ip = ${nic_ip}, expected is 10.10.10.10"
fi
ok "get ${vlan} ip is 10.10.10.10"
