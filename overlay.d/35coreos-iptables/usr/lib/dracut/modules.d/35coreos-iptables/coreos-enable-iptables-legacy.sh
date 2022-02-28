#!/bin/bash
set -euo pipefail

declare -A SYMLINKS=(
    [ip6tables]=ip6tables-legacy
    [ip6tables-restore]=ip6tables-legacy-restore
    [ip6tables-save]=ip6tables-legacy-save
    [iptables]=iptables-legacy
    [iptables-restore]=iptables-legacy-restore
    [iptables-save]=iptables-legacy-save
)

STAMP=/sysroot/etc/coreos/iptables-legacy.stamp
IGNITION_RESULT=/sysroot/etc/.ignition-result.json

# sanity-check the stamp file is present
if [ ! -e "${STAMP}" ]; then
    echo "File ${STAMP} not found; exiting."
    exit 0
fi

# We only want to run once.
rm "${STAMP}"

# Ignore firstboot. We don't want the stamp file to be a long-term
# provisioning-time API for moving to iptables-legacy, so explicitly check for
# this and don't support it. We use the Ignition report file because it's less
# hacky than parsing the kernel commandline for `ignition.firstboot`.
if [ -e "${IGNITION_RESULT}" ]; then
    ignition_boot=$(jq -r .provisioningBootID "${IGNITION_RESULT}")
    if [ "$(cat /proc/sys/kernel/random/boot_id)" = "${ignition_boot}" ]; then
        echo "First boot detected; exiting."
        exit 0
    fi
fi

# if legacy doesn't exist on the host anymore, do nothing
for legacy in "${SYMLINKS[@]}"; do
    path=/sysroot/usr/sbin/$legacy
    if [ ! -e "$path" ]; then
        echo "Executable $path no longer present; exiting."
        exit 0
    fi
done

symlink_is_default() {
    local symlinkpath=$1; shift
    # check that the deployment is still using the symlink (i.e. the user didn't
    # do something funky), and that the OSTree default is still symlink-based
    # (i.e. that we didn't change strategy and forgot to update this script)
    if [ ! -L "/sysroot/$symlinkpath" ] || [ ! -L "/sysroot/usr/$symlinkpath" ]; then
        return 1
    fi
    # compare symlink targets between deployment and OSTree default
    if [ "$(readlink "/sysroot/$symlinkpath")" != "$(readlink "/sysroot/usr/$symlinkpath")" ]; then
        return 1
    fi
    # it's the default
    return 0
}

# If there are any modifications to the symlinks, do nothing. This is basically
# like `ostree admin config-diff` but more focused and lighter/safer than doing
# a bwrap call and grepping output.
for symlink in "${!SYMLINKS[@]}"; do
    symlinkpath=/etc/alternatives/$symlink
    if ! symlink_is_default "$symlinkpath"; then
        echo "Symlink $symlinkpath is not default; exiting without modifying."
        exit 0
    fi
done

# Update symlinks for legacy backend!
for symlink in "${!SYMLINKS[@]}"; do
    target=${SYMLINKS[$symlink]}
    symlink=/etc/alternatives/$symlink
    ln -vsf "/usr/sbin/$target" "/sysroot/$symlink"
    # symlink labels don't matter, but relabel to appease unlabeled_t scanners
    coreos-relabel "$symlink"
done

echo "Updated /sysroot to use iptables-legacy."
