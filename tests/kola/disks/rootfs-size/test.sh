#!/bin/bash
## kola:
##   exclusive: false
##   creationDate: 2026-09-22
##   description: |
##     Verify the provisioned root partition is reasonably sized: we check
##     the actual rootfs content against what was computed for it at
##     build time (see inject_disk_yaml() in build-rootfs)
set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# The minimum percentage of free space we want to have, relative to the
# root partition size that was computed at build time.
MINIMUM_PERCENT_FREE=25

# The finalized root partition size (as injected by inject_disk_yaml() in
# build-rootfs) is baked into the image-builder disk config, which ships
# in the final OS.
disk_yaml=/usr/lib/image-builder/bootc/disk.yaml
design_mib=$(awk '
    /^  - / { in_root=0 }
    /label: root$/ { in_root=1 }
    in_root && /^    size:/ { print $2; exit }
' "${disk_yaml}")

if [ -z "${design_mib}" ]; then
    fatal "Could not determine the designed root partition size from ${disk_yaml}"
fi
design_bytes=$((design_mib * 1024 * 1024))

# Actual bytes used on the root partition. This reflects real content
# size and is essentially unaffected by growfs having grown the
# filesystem, so it's safe to compare against the build-time design size
# above even if growfs already ran on this boot.
used_bytes=$(df --output=used --block-size=1 /sysroot | tail -n 1 | tr -d ' ')

free_percent=$((100 - (used_bytes * 100 / design_bytes)))

if [ "${free_percent}" -lt "${MINIMUM_PERCENT_FREE}" ]; then
    fatal "Not enough free space relative to the designed rootfs size (${design_mib} MiB): only ${free_percent}% free"
fi

ok
