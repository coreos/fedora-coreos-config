#!/bin/bash
## kola:
##   tags: "platform-independent"
##   description: Verify that Ignition is able to use `coreos-boot-disk` symlink.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# symlink shouldn't be propogated to real-root
link="/dev/disk/by-id/coreos-boot-disk"
if [[ -h "${link}" ]]; then
    fatal "${link} still exists"
fi

# sanity-check that the root disk has all required partitions
findmnt -nvr -o SOURCE /boot
findmnt -nvr -o SOURCE /sysroot
toor=$(findmnt -nvr -o SOURCE /var/lib/toor)
if [[ ! "$toor" =~ ^/dev/[a-z0-9]+p?5$ ]]; then
    fatal "${toor} is not 5th partition"
fi
