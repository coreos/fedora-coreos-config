#!/bin/bash
## kola:
##   creationDate: 2026-07-10
##   description: |
##     Disable ignition-ostree-growfs.service
##     and verify the provisionned root partition is
##     reasonnablly sized. We want enough to hold the
##     ostree commit contents + 35% on top.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# The minimum of available free space we want to have.
MINIMUN_PERCENT_FREE=25

# read % of used disk on /sysroot
sysroot_used=$(df --output=pcent /sysroot | tail -n 1 | tr -d ' %')
sysroot_free=$((100 - sysroot_used))

if [ $MINIMUN_PERCENT_FREE -lt "$sysroot_free" ]; then
   fatal "Not enough free space on the rootfs partition: $sysroot_used%. Required minimum is $MINIMUN_PERCENT_FREE%"
fi

ok
