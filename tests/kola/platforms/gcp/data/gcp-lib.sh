# This is a library created for our gcp tests

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# check instance has nvme disks count that matches expected
assert_nvme_disk_count() {
    local nvme_info="$1"
    local expected="$2"
    local nvme_count=$(jq -r ".[].Subsystems | length" <<< "${nvme_info}")
    [ "${nvme_count}" == "${expected}" ]
}

# check nvme device
assert_nvme_disk_accessible() {
    local disk=$1
    local nvme_info="$2"
    local nvme_disk=$(jq -r ".[].Subsystems[].Paths[] | select(.Name == \"${disk}\").Name" <<< "${nvme_info}")
    if [ -n "${nvme_disk}" ]; then
        if [ ! -e "/dev/${disk}n1" ]; then
            fatal "instance has nvme device but no ${disk} accessible"
        fi
    else
        fatal "can not find ${disk} on the instance"
    fi
}

# check symlink
assert_expected_symlink_exists() {
    local device=$1
    # Run google_nvme_id to populate ID_SERIAL_SHORT env var
    eval $(/usr/lib/udev/google_nvme_id -d "${device}")
    if [ ! -n "${ID_SERIAL_SHORT:-}" ]; then
        fatal "can not get nvme ${device} ID_SERIAL_SHORT"
    fi

    local link="/dev/disk/by-id/google-${ID_SERIAL_SHORT}"
    if ! ls -l "${link}"; then
        fatal "can not find ${device} symlink ${link}"
    fi
}
