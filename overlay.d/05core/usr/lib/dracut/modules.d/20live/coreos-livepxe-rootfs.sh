#!/bin/bash
# Ensure that a PXE-booted system has a valid rootfs.

set -euo pipefail

# Get rootfs_url karg
set +euo pipefail
. /usr/lib/dracut-lib.sh
rootfs_url=$(getarg coreos.live.rootfs_url=)
set -euo pipefail

if [[ -f /etc/coreos-live-rootfs ]]; then
    # rootfs image was injected via PXE.  Verify that the initramfs and
    # rootfs versions match.
    initramfs_ver=$(cat /etc/coreos-live-initramfs)
    rootfs_ver=$(cat /etc/coreos-live-rootfs)
    if [[ $initramfs_ver != $rootfs_ver ]]; then
        echo "Found initramfs version $initramfs_ver but rootfs version $rootfs_ver." >&2
        echo "Please fix your PXE configuration." >&2
        exit 1
    fi
elif [[ -n "${rootfs_url}" ]]; then
    # rootfs URL was provided as karg.  Fetch image, check its hash, and
    # unpack it.
    echo "Fetching rootfs image from ${rootfs_url}..."
    if [[ ${rootfs_url} != http:* && ${rootfs_url} != https:* ]]; then
        # Don't commit to supporting protocols we might not want to expose in
        # the long term.
        echo "coreos.live.rootfs_url= supports HTTP and HTTPS only." >&2
        echo "Please fix your PXE configuration." >&2
        exit 1
    fi
    # We don't need to verify TLS certificates because we're checking the
    # image hash.
    if ! curl --silent --insecure --location --retry 5 "${rootfs_url}" | \
            rdcore stream-hash /etc/coreos-live-want-rootfs | \
            cpio -i -H newc -D / --quiet ; then
        echo "Couldn't fetch, verify, and unpack image specified by coreos.live.rootfs_url=" >&2
        echo "Check that the URL is correct and that the rootfs version matches the initramfs." >&2
        exit 1
    fi
elif [[ -f /root.squashfs ]]; then
    # Image was built with cosa buildextend-live --legacy-pxe and the user
    # didn't append the rootfs.  Inject a warning MOTD.  Remove this case
    # after the deprecation period.
    mkdir -p /run/motd.d
    cat > /run/motd.d/80-pxe-rootfs.motd <<EOF

[33;1mDetected PXE boot without rootfs image.  Please update your PXE configuration
to add the rootfs image as a second initrd.  Fedora CoreOS PXE images released
after these dates will not boot without a rootfs image:
        next:    August 25, 2020
        testing: September 22, 2020
        stable:  October 6, 2020
https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/#_pxe_rootfs_image[0m

EOF
else
    # Nothing.  Fail.
    echo "No rootfs image found.  Modify your PXE configuration to add the rootfs" >&2
    echo "image as a second initrd, or use the coreos.live.rootfs_url= kernel parameter" >&2
    echo "to specify an HTTP or HTTPS URL to the rootfs." >&2
    exit 1
fi
