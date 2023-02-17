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
    local ip=$(ip -j addr show ${nic_name} | jq -r '.[0].addr_info | map(select(.family == "inet")) | .[0].local')
    if [ -z "$ip" ]; then
        echo "Error: can not get ip for ${nic_name}"
        exit 1
    fi
    echo $ip
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
    [ "${ID}" == "rhcos" ]
}

get_fedora_ver() {
    source /etc/os-release
    if is_fcos; then
        echo "${VERSION_ID}"
    fi
}

get_rhel_maj_ver() {
    source /etc/os-release
    echo "${RHEL_VERSION%%.*}"
}

# rhcos8
is_rhcos8() {
    source /etc/os-release
    [ "${ID}" == "rhcos" ] && [ "${RHEL_VERSION%%.*}" -eq 8 ]
}

# rhcos9
is_rhcos9() {
    source /etc/os-release
    [ "${ID}" == "rhcos" ] && [ "${RHEL_VERSION%%.*}" -eq 9 ]
}

# scos
is_scos() {
    source /etc/os-release
    [ "${ID}" == "scos" ] && [ "${VARIANT_ID}" == "coreos" ]
}

cmdline=( $(</proc/cmdline) )
cmdline_arg() {
    local name="$1" value=""
    for arg in "${cmdline[@]}"; do
        if [[ "${arg%%=*}" == "${name}" ]]; then
            value="${arg#*=}"
        fi
    done
    echo "${value}"
}

# wait for 20s when in activating status
is_service_active() {
    local service="$1"
    for x in {0..20}; do
        [ $(systemctl is-active "${service}") != "activating" ] && break
        sleep 1
    done
    # return actual result
    systemctl is-active "${service}"
}
