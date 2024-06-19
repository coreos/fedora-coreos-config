#!/bin/bash
## kola:
##   tags: "platform-independent"
##   description: Verify that the fallback hostname is `localhost`.

# This test validates that the fallback hostname is set to `localhost`
# by first disabling NetworkManager from setting the hostname
# via DHCP or DNS (see config.bu), also verify that the
# hostname is set from the fallback hostname and is `localhost`.
# See https://github.com/coreos/fedora-coreos-tracker/issues/902
#
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
#
# "hostnamectl --json=pretty" is not supported on rhel8 yet, the
# expected output like this:
#    Static hostname: n/a
# Transient hostname: localhost
#          Icon name: computer-vm
#            Chassis: vm
#         Machine ID: d9d6dbacde8345f2a275e1d6dca81b78
#            Boot ID: a47ef11ca938496985d5d85a4274c664
#     Virtualization: kvm
#   Operating System: Red Hat Enterprise Linux CoreOS 412.86.202209030446-0 (Ootpa)
#        CPE OS Name: cpe:/o:redhat:enterprise_linux:8::coreos
#             Kernel: Linux 4.18.0-372.19.1.el8_6.x86_64
#       Architecture: x86-64

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

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
