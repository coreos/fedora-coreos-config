#!/bin/bash
set -xeuo pipefail

# kola: { "distros": "fcos", "platforms": "qemu" }
#
# Test that the fallback hostname is `localhost`. This test
# validates that the fallback hostname is set to `localhost`
# by first disabling NetworkManager from setting the hostname
# via DHCP or DNS (see config.bu) and then verifying that the
# hostname is set from the fallback hostname and is `localhost`.
# https://github.com/coreos/fedora-coreos-tracker/issues/902
#
# - distros: fcos
#   - The change only landed in fedora
# - platforms: qemu
#   - This test should pass everywhere if it passes anywhere.

. $KOLA_EXT_DATA/commonlib.sh

# Use the output of hostnamectl to gather information about how
# the hostname is/was set. We're expecting something like this:
#   {
#       "Hostname" : "localhost",
#       "StaticHostname" : null,
#       "PrettyHostname" : null,
#       "DefaultHostname" : "localhost",
#       "HostnameSource" : "default",
#       "IconName" : "computer-vm",
#       "Chassis" : "vm",
#       "Deployment" : null,
#       "Location" : null,
#       "KernelName" : "Linux",
#       "KernelRelease" : "5.18.17-200.fc36.x86_64",
#       "KernelVersion" : "#1 SMP PREEMPT_DYNAMIC Thu Aug 11 14:36:06 UTC 2022",
#       "OperatingSystemPrettyName" : "Fedora CoreOS 36.20220814.20.0",
#       "OperatingSystemCPEName" : "cpe:/o:fedoraproject:fedora:36",
#       "OperatingSystemHomeURL" : "https://getfedora.org/coreos/",
#       "HardwareVendor" : "QEMU",
#       "HardwareModel" : "Standard PC _i440FX + PIIX, 1996_",
#       "ProductUUID" : null
#   }


output=$(hostnamectl --json=pretty)
hostname=$(echo "$output" | jq -r '.Hostname')
fallback=$(echo "$output" | jq -r '.DefaultHostname')
static=$(echo "$output" | jq -r '.StaticHostname')
namesource=$(echo "$output" | jq -r '.HostnameSource')

if [ "$hostname" != 'localhost' ]; then
    fatal "hostname was not expected"
fi
if [ "$fallback" != 'localhost' ]; then
    fatal "fallback hostname was not expected"
fi
if [ "$static" != 'null' ]; then
    fatal "static hostname not expected to be set"
fi
if [ "$namesource" != 'default' ]; then
    # For this test since we disabled NM setting the hostname we
    # expect the hostname to have been set via the fallback/default
    fatal "hostname was set from non-default/fallback source"
fi

ok "fallback hostname wired up correctly"
