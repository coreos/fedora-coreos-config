#!/bin/bash
# We support both SquashFS and EROFS. The image is embedded in
# ISO images/pxeboot/rootfs.img and located at offset 124. This
# detects the exact filesystem type of the root filesystem by
# reading the magic number of SquashFS at the hardcoded offset.

set -euo pipefail

rootfs=/run/media/iso/images/pxeboot/rootfs.img

if [[ ! -f "${rootfs}" ]]; then
    echo "Cannot find ${rootfs}"
    exit 1
fi

# In cosa & osbuild we rely only on magic number, so let's follow that.
# Other way would be to read the filename:
# $ fstype=$(dd if=${rootfs} skip=$((124-14)) bs=1 count=14 status=none)
# $ root.squasfs
magic_squashfs=$(dd if="${rootfs}" skip=124 bs=1 count=4 status=none)
if [[ "${magic_squashfs}" == "hsqs" ]]; then
    fstype=squashfs
else
    # EROFS magic number is non ASCII bytes
    # $ od -j$((124+1024)) -N 4 -t x ${rootfs} --endian=big -A none -w 4
    # $ e2e1f5e0
    fstype=erofs
fi

# Let sysroot.mount know what path and type to use for mounting
echo "Updating /rootfs.env with TYPE=${fstype}"
cat >/rootfs.env <<EOF
TYPE=${fstype}
EOF
