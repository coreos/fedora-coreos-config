#!/bin/bash
## kola:
##   # This test requires changing instance types and must
##   # be run exclusively.
##   exclusive: true
##   # This test is targeted at Azure
##   platforms: azure
##   # attach an NVMe data disk to the instance
##   additionalDisks: ["30G:sku=UltraSSD_LRS"]
##   # This test requires an instance type that supports NVMe
##   instanceType: "Standard_M16bds_v3"
##   description: Verify that udev rules for Azure Managed NVMe disks
##                correctly create stable symlinks under /dev/disk/azure.

set -xeuo pipefail

. "$KOLA_EXT_DATA/commonlib.sh"

# Wait up to 30 seconds for a symlink to be created.
wait_for_symlink() {
    local path="$1"
    local timeout=30
    while [ ! -L "$path" ] && [ "$timeout" -gt 0 ]; do
        sleep 1
        timeout=$((timeout - 1))
    done
    if [ ! -L "$path" ]; then
        fatal "Timed out waiting for symlink $path to appear"
    fi
}

# Verify OS disk symlink
azure_os_symlink="/dev/disk/azure/os"
wait_for_symlink "$azure_os_symlink"
if [ ! -e "$azure_os_symlink" ]; then
    fatal "symlink $azure_os_symlink exists but points to a missing target"
fi

# Verify data disk symlink
azure_data_symlink="/dev/disk/azure/data/by-lun/0"
wait_for_symlink "$azure_data_symlink"
if [ ! -e "$azure_data_symlink" ]; then
    fatal "symlink $azure_data_symlink exists but points to a missing target"
fi
