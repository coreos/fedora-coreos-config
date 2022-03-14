#!/bin/bash
# kola: { "exclusive": false, "platforms": "qemu-unpriv" }
# No need to run on any other platform than QEMU.

set -xeuo pipefail

# Since we depend so much on the default networking configurations let's
# alert ourselves when any default networking configuration changes in
# NetworkManager. This allows us to react and adjust to the changes
# (if needed) instead of finding out later that problems were introduced.
# some context in: https://github.com/coreos/fedora-coreos-tracker/issues/1000

. $KOLA_EXT_DATA/commonlib.sh

# EXPECTED_INITRD_NETWORK_CFG1
#   - used on Fedora 35 and RHEL 8.5 release
EXPECTED_INITRD_NETWORK_CFG1="[connection]
id=Wired Connection
uuid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
type=ethernet
autoconnect-retries=1
multi-connect=3
permissions=

[ethernet]
mac-address-blacklist=

[ipv4]
dhcp-timeout=90
dns-search=
method=auto
required-timeout=20000

[ipv6]
addr-gen-mode=eui64
dhcp-timeout=90
dns-search=
method=auto

[proxy]

[user]
org.freedesktop.NetworkManager.origin=nm-initrd-generator"
# EXPECTED_INITRD_NETWORK_CFG2
#   - used on older RHEL 8.4 release
EXPECTED_INITRD_NETWORK_CFG2="[connection]
id=Wired Connection
uuid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
type=ethernet
autoconnect-retries=1
multi-connect=3
permissions=

[ethernet]
mac-address-blacklist=

[ipv4]
dhcp-timeout=90
dns-search=
method=auto
required-timeout=20000

[ipv6]
addr-gen-mode=eui64
dhcp-timeout=90
dns-search=
method=auto

[proxy]"
# EXPECTED_INITRD_NETWORK_CFG3
#   - used on Fedora 36+ and RHEL8.6+
EXPECTED_INITRD_NETWORK_CFG3="[connection]
id=Wired Connection
uuid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
type=ethernet
autoconnect-retries=1
multi-connect=3

[ethernet]

[ipv4]
dhcp-timeout=90
method=auto
required-timeout=20000

[ipv6]
addr-gen-mode=eui64
dhcp-timeout=90
method=auto

[proxy]

[user]
org.freedesktop.NetworkManager.origin=nm-initrd-generator"

# EXPECTED_REALROOT_NETWORK_CFG1:
#   - used on F35 and RHEL <= 8.5
EXPECTED_REALROOT_NETWORK_CFG1="[connection]
id=Wired connection 1
uuid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
type=ethernet
autoconnect-priority=-999
interface-name=xxxx
permissions=
timestamp=xxxxxxxxxx

[ethernet]
mac-address-blacklist=

[ipv4]
dns-search=
method=auto

[ipv6]
addr-gen-mode=stable-privacy
dns-search=
method=auto

[proxy]

[.nmmeta]
nm-generated=true"
# EXPECTED_REALROOT_NETWORK_CFG2:
#   - used on all Fedora 36+ and RHEL8.6+
EXPECTED_REALROOT_NETWORK_CFG2="[connection]
id=Wired connection 1
uuid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
type=ethernet
autoconnect-priority=-999
interface-name=xxxx
timestamp=xxxxxxxxxx

[ethernet]

[ipv4]
method=auto

[ipv6]
addr-gen-mode=stable-privacy
method=auto

[proxy]

[.nmmeta]
nm-generated=true"

# Function that will remove unique (per-run) data from a connection file
normalize_connection_file() {
    sed -e s/^uuid=.*$/uuid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/ \
        -e s/^timestamp=.*$/timestamp=xxxxxxxxxx/                 \
        -e s/^interface-name=.*$/interface-name=xxxx/             \
        "${1}"
}

source /etc/os-release
# All current FCOS releases use the same config
# https://github.com/coreos/fedora-coreos-config/pull/1533
if [ "$ID" == "fedora" ]; then
    if [ "$VERSION_ID" -ge "36" ]; then
        EXPECTED_INITRD_NETWORK_CFG=$EXPECTED_INITRD_NETWORK_CFG3
        EXPECTED_REALROOT_NETWORK_CFG=$EXPECTED_REALROOT_NETWORK_CFG2
    elif [ "$VERSION_ID" -eq "35" ]; then
        EXPECTED_INITRD_NETWORK_CFG=$EXPECTED_INITRD_NETWORK_CFG1
        EXPECTED_REALROOT_NETWORK_CFG=$EXPECTED_REALROOT_NETWORK_CFG1
    else
        fatal "fail: not operating on expected OS version"
    fi
elif [ "$ID" == "rhcos" ]; then
    # For the version comparison use string substitution to remove the
    # '.` from the version so we can use integer comparison
    # RHEL8.6 includes NetworkManager-1.36.0-1.el8.x86_64, update scripts
    # according to F36
    if [ "${RHEL_VERSION/\./}" -ge 86 ]; then
        EXPECTED_INITRD_NETWORK_CFG=$EXPECTED_INITRD_NETWORK_CFG3
        EXPECTED_REALROOT_NETWORK_CFG=$EXPECTED_REALROOT_NETWORK_CFG2
    elif [ "${RHEL_VERSION/\./}" -eq 85 ]; then
        EXPECTED_INITRD_NETWORK_CFG=$EXPECTED_INITRD_NETWORK_CFG1
        EXPECTED_REALROOT_NETWORK_CFG=$EXPECTED_REALROOT_NETWORK_CFG1
    elif [ "${RHEL_VERSION/\./}" -eq 84 ]; then
        EXPECTED_INITRD_NETWORK_CFG=$EXPECTED_INITRD_NETWORK_CFG2
        EXPECTED_REALROOT_NETWORK_CFG=$EXPECTED_REALROOT_NETWORK_CFG1
    else
        fatal "fail: not operating on expected OS version"
    fi
else
    fatal "fail: not operating on expected OS"
fi


# Execute nm-initrd-generator against our default kargs (defined by
# afterburn drop in) to get the generated initrd network config.
DEFAULT_KARGS_FILE=/usr/lib/dracut/modules.d/35coreos-network/50-afterburn-network-kargs-default.conf
source <(grep -o 'AFTERBURN_NETWORK_KARGS_DEFAULT=.*' $DEFAULT_KARGS_FILE)
tmpdir=$(mktemp -d)
/usr/libexec/nm-initrd-generator \
    -c "${tmpdir}/connections" \
    -i "${tmpdir}/initrd-data-dir" \
    -r "${tmpdir}/conf.d" \
    -- $AFTERBURN_NETWORK_KARGS_DEFAULT
GENERATED_INITRD_NETWORK_CFG=$(normalize_connection_file \
                               "${tmpdir}/connections/default_connection.nmconnection")

# Diff the outputs and fail if the expected doesn't match the generated.
if ! diff -u <(echo "$EXPECTED_INITRD_NETWORK_CFG") <(echo "$GENERATED_INITRD_NETWORK_CFG"); then
    fatal "fail: the expected initrd network config is not given by the kargs"
fi

# Check the default NetworkManager runtime generated connection profile in
# the real root to make sure it matches what we expect.
GENERATED_REALROOT_NETWORK_CFG=$(normalize_connection_file \
                                 <(sudo cat "/run/NetworkManager/system-connections/Wired connection 1.nmconnection"))
if ! diff -u <(echo "$EXPECTED_REALROOT_NETWORK_CFG") <(echo "$GENERATED_REALROOT_NETWORK_CFG"); then
    fatal "fail: the expected realroot network config is not given by the kargs"
fi
ok "success: expected network configs were generated"
