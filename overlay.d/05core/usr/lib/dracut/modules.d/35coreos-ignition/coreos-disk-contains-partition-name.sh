#!/bin/bash
# checks whether `disk` contains partition labeled `label`
set -euo pipefail

disk=$1
label=$2

# copied from generator-lib.sh
karg() {
    local name="$1" value="${2:-}"
    local cmdline=( $(</proc/cmdline) )
    for arg in "${cmdline[@]}"; do
        if [[ "${arg%%=*}" == "${name}" ]]; then
            value="${arg#*=}"
            break
        fi
    done
    echo "${value}"
}

multipath=$(karg "rd.multipath")
if  [[ -n ${multipath} ]]; then
    if [[ ! -f /sys/block/${disk}/dm/name ]]; then
        exit 1
    fi
fi

if sfdisk "/dev/${disk}" --json | jq -e '.partitiontable.partitions | any(.name == "'"${label}"'")'; then
    exit 0
fi

exit 1

