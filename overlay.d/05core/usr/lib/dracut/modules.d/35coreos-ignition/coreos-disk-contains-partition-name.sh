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

# On Fedora (with /bin_/sbin merge), sfdisk is located at /usr/bin/sfdisk,
# so udev helper scripts find it automatically via PATH. On RHEL/RHCOS 9.6,
# sfdisk resides in /usr/sbin, but udev worker processes reset PATH to a
# minimal environment (/usr/local/bin:/usr/bin), causing scripts that call
# 'sfdisk' without the full path to fail. So we need this to find the full
# sfdisk path.
# See https://github.com/coreos/fedora-coreos-config/pull/3862#issuecomment-3467947591
sfdisk_cmd=''
for f in /usr/bin/sfdisk /usr/sbin/sfdisk; do
    if [ -x "${f}" ]; then
        sfdisk_cmd="${f}"
        break
    fi
done

if [ -n "${sfdisk_cmd}" ] && ${sfdisk_cmd} "/dev/${disk}" --json | jq -e '.partitiontable.partitions | any(.name == "'"${label}"'")'; then
    exit 0
fi

exit 1
