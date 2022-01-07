#!/bin/bash
set -euo pipefail

# First check to see if the requested state is satisfied by the current boot
/usr/bin/rdcore kargs --current --create-if-changed /run/coreos-kargs-thisboot-differ "$@"

if is-live-image; then
	# If we're in a live system and the kargs don't match then we must error.
    if [ -e /run/coreos-kargs-thisboot-differ ]; then
        # Since we exit with error here the stderr will get shown by Ignition
        echo "Need to modify kernel arguments, but cannot affect live system." >&2
        exit 1
    fi
else
    /usr/bin/rdcore kargs --boot-device /dev/disk/by-label/boot --create-if-changed /run/coreos-kargs-changed "$@"
    # If the bootloader was changed and the kernel arguments don't match this boot
    # then we must reboot. If they do match this boot then we can skip the reboot.
    #
    # Note we write info messages to kmsg here because stdout gets swallowed
    # by Ignition if there is no failure. This forces the info into the journal,
    # but sometimes the journal will miss these messages because of ratelimiting.
    # We've decided to accept this limitation rather than add the systemd-cat or
    # logger utlities to the initramfs.
    if [ -e /run/coreos-kargs-changed ]; then
        if [ -e /run/coreos-kargs-thisboot-differ ]; then
            msg="Kernel arguments were changed. Requesting reboot."
            echo "$msg" > /dev/kmsg
            touch /run/coreos-kargs-reboot
        else
            msg="Kernel arguments were changed, but they match this boot. Skipping reboot."
            echo "$msg" > /dev/kmsg
        fi
    fi
fi
