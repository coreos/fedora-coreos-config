#!/bin/bash
# checks and aborts the boot if system has several partitions with label specified by $1

set -euo pipefail

# ensure all disks are discovered
udevadm trigger
udevadm settle

# read non-empty WWN to skip multipath disks
PARTITIONS=()
mapfile -t PARTITIONS < <(lsblk -o WWN,LABEL,NAME --pairs --paths --noheadings | sed 's/WWN=\"\" //' | grep "LABEL=\""$1"\"" | sort -u -k1,2)

LENGTH=${#PARTITIONS[@]}
if [[ ${LENGTH} -gt 1 ]]; then
    echo "System has "${LENGTH}" partitions with '"$1"' label:"
    for PT in "${PARTITIONS[@]}"; do
        echo "${PT}"
    done
    echo "Please 'wipefs' other partitions/disks and reboot. Aborting..."
    exit 1
fi
