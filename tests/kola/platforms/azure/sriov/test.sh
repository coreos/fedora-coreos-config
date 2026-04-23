#!/bin/bash
## kola:
##   # This test is targeted at Azure
##   platforms: azure
##   description: Verify that udev rules for Azure SRIOV network interfaces
##                correctly mark them as unmanaged by NetworkManager.

set -xeuo pipefail

. "$KOLA_EXT_DATA/commonlib.sh"

# Find SRIOV network interfaces
# Azure SR-IOV interfaces use Mellanox drivers (mlx4_core or mlx5_core)
sriov_interfaces=()
for iface in /sys/class/net/*; do
    iface_name=$(basename "$iface")
    # Skip loopback
    if [ "$iface_name" = "lo" ]; then
        continue
    fi

    if [ -e "$iface/device/driver" ]; then
        driver=$(basename "$(readlink "$iface/device/driver")")
        # SR-IOV interfaces on Azure use Mellanox drivers (mlx4_core or mlx5_core)
        if [ "$driver" = "mlx4_core" ] || [ "$driver" = "mlx5_core" ]; then
            sriov_interfaces+=("$iface_name")
        fi
    fi
done

# If no SRIOV interfaces found then this might be a VM size without Accelerated Networking
# or the feature might not be enabled. We should have at least one SRIOV interface.
if [ ${#sriov_interfaces[@]} -eq 0 ]; then
    fatal "No SRIOV interfaces found, expected at least one Mellanox (mlx4_core/mlx5_core) network interface."
fi

# Check that each SRIOV interface has the AZURE_UNMANAGED_SRIOV property set
# This property is set by the azure-vm-utils udev rules
for iface in "${sriov_interfaces[@]}"; do
    # Check the interface properties
    if ! udevadm info --query=property --path="/sys/class/net/$iface" | grep -q "AZURE_UNMANAGED_SRIOV=1"; then
        fatal "SRIOV interface $iface does not have AZURE_UNMANAGED_SRIOV=1 property."
    fi
done

nm_devices=$(nmcli -t -f DEVICE,STATE device)

for iface in "${sriov_interfaces[@]}"; do
    if ! echo "$nm_devices" | grep -q "^$iface:"; then
        fatal "SRIOV interface $iface not found in NetworkManager output."
    fi
    state=$(echo "$nm_devices" | grep "^$iface:" | cut -d: -f2)
    if [ "$state" != "unmanaged" ]; then
        fatal "NetworkManager is managing SRIOV interface $iface (state: $state). It should be unmanaged."
    fi
done
