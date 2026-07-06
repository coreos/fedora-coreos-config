#!/bin/bash
## kola:
##   # additionalDisks is only supported on qemu.
##   platforms: qemu
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # Linear RAID is setup on these disks.
##   additionalDisks: ["10G"]
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   architectures: "x86_64"
##   description: Verify updating the bootloader while using RAID 1 works.
##   creationDate: 2026-05-06

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib_raid1.sh"

check_raid1_boot
