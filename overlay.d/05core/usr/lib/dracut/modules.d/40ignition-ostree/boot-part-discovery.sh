#!/bin/bash

XBOOTLDR_UUID="BC13C2FF-59E6-4262-A352-B275FD6F7172"
BOOT_STATUS_DIR="/run/coreos"
BOOT_STATUS_FILE="${BOOT_STATUS_DIR}/boot-partition-status"

boot_part_exists() {
    LSBLK_JSON="$(lsblk -o name,parttype,uuid,mountpoint,parttypename,label --json)"

    while read -r part; do
        parttype="$(jq -r '.parttype // empty' <<<"$part" | tr '[:lower:]' '[:upper:]')"
        name="$(jq -r '.name' <<<"$part")"

        [[ -n "$parttype" ]] || echo "Partition '$name' has no parttype"

        if [[ "$parttype" == "$XBOOTLDR_UUID" ]]; then
            return 0
        fi
    done < <(echo "$LSBLK_JSON" | jq -c '.blockdevices[].children[]?')

    return 1
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if boot_part_exists; then
        mkdir -p "$BOOT_STATUS_DIR"
        echo "available" > "$BOOT_STATUS_FILE"
    else
        echo "Boot partition not found"
    fi
fi
