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
    # bsdtar can read cpio archives and we already depend on it for
    # coreos-liveiso-persist-osmet.service, so use it instead of cpio.
    if ! curl --silent --show-error --insecure --location --retry 5 "${rootfs_url}" | \
            rdcore stream-hash /etc/coreos-live-want-rootfs | \
            bsdtar -xf - -C / ; then
        echo "Couldn't fetch, verify, and unpack image specified by coreos.live.rootfs_url=" >&2
        echo "Check that the URL is correct and that the rootfs version matches the initramfs." >&2
        exit 1
    fi
else
    # Nothing.  Fail.
    echo "No rootfs image found.  Modify your PXE configuration to add the rootfs" >&2
    echo "image as a second initrd, or use the coreos.live.rootfs_url= kernel parameter" >&2
    echo "to specify an HTTP or HTTPS URL to the rootfs." >&2
    exit 1
fi
