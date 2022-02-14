#!/bin/bash
# checks whether `disk` contains filesystem labeled `label`
set -euo pipefail

disk=$1
label=$2

# during execution of udev rules on disks 'lsblk' returns empty fields
for pt in /sys/block/$disk/*; do
    name=$(basename $pt)
    if [[ "$name" =~ ${disk}p?[[:digit:]] ]] && [[ -e "/sys/block/$disk/$name/start" ]];
    then
        eval $(udevadm info --query=property -n /dev/$name | grep -e ID_FS_LABEL -e PARTNAME)
        if [[ "${ID_FS_LABEL:-}" == "$label" ]] || [[ "${PARTNAME:-}" == "$label" ]]; then
            exit 0
        fi
    fi
done

exit 1
