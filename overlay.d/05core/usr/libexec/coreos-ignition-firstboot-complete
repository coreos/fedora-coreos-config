#!/bin/bash
set -euo pipefail

mount -o remount,rw /boot

if [[ $(uname -m) = s390x ]]; then
    zipl
fi

# Regarding the lack of `-f` for rm ; we should have only run if GRUB detected
# this file. Fail if we are unable to remove it, rather than risking rerunning
# Ignition at next boot.
rm /boot/ignition.firstboot
