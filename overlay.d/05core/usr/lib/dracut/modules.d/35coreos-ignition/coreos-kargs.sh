#!/bin/bash
set -euo pipefail


# There are a few cases we need to handle here. To illustrate this
# we'll use scenarios below where:
#
# - "booted":   The kernel arguments from the currently booting system.
# - "ignition": The kernel arguments in the Ignition configuration.
# - "bls":      The kernel arguments currently baked into the disk
#               image BLS configs.
#
# The scenarios are:
#
# A.
#   - Scenario:
#       - booted: ""
#       - ignition: "foobar"
#       - bls: ""
#   - Action: -> Update BLS configs, perform reboot
# B.
#   - Scenario:
#       - booted: "foobar"
#       - ignition: "foobar"
#       - bls: ""
#   - Action: -> Update BLS configs, skip reboot
# C.
#   - Scenario:
#       - booted: ""
#       - ignition: "foobar"
#       - bls: "foobar"
#   - Action: -> Skip update of BLS configs (they match already), perform reboot
#
# The logic here boils down to:
#   if "ignition" != "booted"; then needreboot=1; fi
#   if "ignition" != "bls"; then updatebls(); fi

# NOTE: we write info messages to kmsg here because stdout gets swallowed
#       by Ignition if there is no failure. This forces the info into the
#       journal, but sometimes the journal will miss these messages because
#       of ratelimiting. We've decided to accept this limitation rather than
#       add the systemd-cat or logger utlities to the initramfs.

# If the desired state isn't reflected by the current boot we'll need to reboot.
/usr/bin/rdcore kargs --current --create-if-changed /run/coreos-kargs-reboot "$@"
if [ -e /run/coreos-kargs-reboot ]; then
    msg="Desired kernel arguments don't match current boot. Requesting reboot."
    echo "$msg" > /dev/kmsg
fi

if is-live-image; then
	# If we're in a live system and the kargs don't match then we must error.
    if [ -e /run/coreos-kargs-reboot ]; then
        # Since we exit with error here the stderr will get shown by Ignition
        echo "Need to modify kernel arguments, but cannot affect live system." >&2
        exit 1
    fi
else
    # Update the BLS configs if they need to be updated.
    /usr/bin/rdcore kargs --boot-device /dev/disk/by-label/boot --create-if-changed /run/coreos-kargs-changed "$@"
    if [ -e /run/coreos-kargs-changed ]; then
        msg="Kernel arguments in BLS config were updated."
        echo "$msg" > /dev/kmsg
    fi
fi
