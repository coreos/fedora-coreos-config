# shellcheck shell=bash
# This is a common library created for the ok & fatal function and symlinks
# added to the data/ in each directory

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

get_ipv4_for_nic() {
    local nic_name=$1
    local ip
    ip="$(ip -j addr show "${nic_name}" | jq -r '.[0].addr_info | map(select(.family == "inet")) | .[0].local')"
    if [ -z "$ip" ]; then
        echo "Error: can not get ip for ${nic_name}"
        exit 1
    fi
    echo "$ip"
}

get_fedora_container_ref() {
    local repo='quay.io/fedora/fedora'
    local tag='41'
    echo "${repo}:${tag}"
}

get_fedora_minimal_container_ref() {
    local repo='quay.io/fedora/fedora-minimal'
    local tag='41'
    echo "${repo}:${tag}"
}

get_fcos_stream() {
    rpm-ostree status -b --json | jq -r '.deployments[0]["base-commit-meta"]["fedora-coreos.stream"]'
}

is_fcos() {
    source /etc/os-release
    [ "${ID}" == "fedora" ] && [ "${VARIANT_ID}" == "coreos" ]
}

# Note when using this, you probably also want to check `get_rhel_maj_ver`.
is_rhcos() {
    source /etc/os-release
    { [ "${ID}" == "rhel" ] && [ "${VARIANT_ID}" == "coreos" ]; } || \
    [ "${ID}" == "rhcos" ]
}

get_fedora_ver() {
    source /etc/os-release
    if is_fcos; then
        echo "${VERSION_ID}"
    fi
}

get_rhel_ver() {
    source /etc/os-release
    if [ "${ID}" == "rhcos" ]; then
        echo "${RHEL_VERSION}"
    elif [ "${ID}" == "rhel" ]; then
        echo "${VERSION_ID}"
    else
        fatal "Unknown ID $ID"
    fi
}

get_rhel_maj_ver() {
    local ver; ver=$(get_rhel_ver)
    echo "${ver%%.*}"
}

# rhcos9
is_rhcos9() {
    source /etc/os-release
    { [ "${ID}" == "rhcos" ] && [ "${RHEL_VERSION%%.*}" -eq 9 ]; } || \
    { [ "${ID}" == "rhel" ] && [ "${VERSION_ID%%.*}" -eq 9 ]; }
}

# scos
is_scos() {
    source /etc/os-release
    { [ "${ID}" == "scos" ] || [ "${ID}" == "centos" ]; } && [ "${VARIANT_ID}" == "coreos" ]
}

IFS=" " read -r -a cmdline <<< "$(</proc/cmdline)"
cmdline_arg() {
    local name="$1" value=""
    for arg in "${cmdline[@]}"; do
        if [[ "${arg%%=*}" == "${name}" ]]; then
            value="${arg#*=}"
        fi
    done
    echo "${value}"
}

# wait for ~60s when in activating status
is_service_active() {
    local service="$1"; shift
    local timeout="${1:-60}"; shift
    for _x in $(seq "${timeout}"); do
        [ "$(systemctl is-active "${service}")" != "activating" ] && break
        sleep 1
    done
    # return actual result
    systemctl is-active "${service}"
}

## Some functions to support version comparison
# Returns true iff $1 is equal to $2
vereq() {
    [ "$1" == "$2" ]
}

# Returns true iff $1 is less than $2
verlt() {
    vereq "$1" "$2" && return 1
    local lowest
    lowest="$(echo -e "$1\n$2" | sort -V | head -n 1)"
    [ "$1" == "$lowest" ]
}

# Returns true iff $1 is less than or equal to $2
verlte() {
    vereq "$1" "$2" || verlt "$1" "$2"
}

# Returns true iff $1 is greater than to $2
vergt() {
    ! verlte "$1" "$2"
}

# Returns true iff $1 is greater than or equal to $2
vergte() {
    vereq "$1" "$2" || vergt "$1" "$2"
}
