# File intended to be sourced by shell script generators shipped with CoreOS systems

# Generators don't have logging right now
# https://github.com/systemd/systemd/issues/15638
exec 1>/dev/kmsg; exec 2>&1

UNIT_DIR="${1:-/tmp}"

have_karg() {
    local arg="$1"
    local cmdline=( $(</proc/cmdline) )
    local i
    for i in "${cmdline[@]}"; do
        if [[ "$i" =~ "$arg=" ]]; then
            return 0
        fi
    done
    return 1
}

karg() {
    local name="$1" value="${2:-}"
    local cmdline=( $(</proc/cmdline) )
    for arg in "${cmdline[@]}"; do
        if [[ "${arg%%=*}" == "${name}" ]]; then
            value="${arg#*=}"
        fi
    done
    echo "${value}"
}
