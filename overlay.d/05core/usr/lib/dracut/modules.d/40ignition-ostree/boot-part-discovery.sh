#!/bin/bash

set -euo pipefail

BOOT_STATUS_DIR="/run/coreos"
BOOT_STATUS_FILE="${BOOT_STATUS_DIR}/boot-partition-status"

mkdir -p "$BOOT_STATUS_DIR"

XBOOTLDR_UUID="BC13C2FF-59E6-4262-A352-B275FD6F7172"

LSBLK_JSON="$(lsblk -o name,parttype,uuid,mountpoint,parttypename,label --json)"

while read -r part; do
    parttype="$(jq -r '.parttype // empty' <<<"$part" | tr '[:lower:]' '[:upper:]')"
    name="$(jq -r '.name' <<<"$part")"

    [[ -n "$parttype" ]] || echo "Partition '$name' has no parttype"

    if [[ "$parttype" == "$XBOOTLDR_UUID" ]]; then
        echo "available" > "$BOOT_STATUS_FILE"
        break
    else
        echo "not boot"
    fi
done < <(echo "$LSBLK_JSON" | jq -c '.blockdevices[].children[]?')
