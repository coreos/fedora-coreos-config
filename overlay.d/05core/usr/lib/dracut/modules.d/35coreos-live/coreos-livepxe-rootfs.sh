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
    if [[ ${rootfs_url} != http:* && ${rootfs_url} != https:* && ${rootfs_url} != tftp:* ]]; then
        # Don't commit to supporting protocols we might not want to expose in
        # the long term.
        echo "Unsupported scheme for image specified by:" >&2
        echo "coreos.live.rootfs_url=${rootfs_url}" >&2
        echo "Only HTTP, HTTPS, and TFTP are supported. Please fix your PXE configuration." >&2
        exit 1
    fi

    # First, reach out to the server to verify connectivity before
    # trying to download and pipe content through other programs.
    # Doing this allows us to retry all errors (including transient
    # "no route to host" errors during startup). Note we can't use
    # curl's --retry-all-errors here because it's not in el8's curl yet.
    # We don't need to verify TLS certificates because we're checking the
    # image hash. We retry forever, matching Ignition's semantics.
    curl_common_args="--silent --show-error --insecure --location"
    while ! curl --head $curl_common_args "${rootfs_url}" >/dev/null; do
        echo "Couldn't establish connectivity with the server specified by:" >&2
        echo "coreos.live.rootfs_url=${rootfs_url}" >&2
        echo "Retrying in 5s..." >&2
        sleep 5
    done

    # We shouldn't need a --retry from here on since we've just successfully
    # HEADed the file, but let's add one just to be safe (e.g. if the
    # connection just went online and flickers or something).
    curl_common_args+=" --retry 5"

    # Do a HEAD again but just once and with `--fail` so that if e.g. it's
    # missing, we get a clearer error than if it were part of the pipeline
    # below. Otherwise, the `curl` error emitted there would get lost among
    # all the spurious errors from the other commands in that pipeline and also
    # wouldn't show up in the journal logs dumped by `emergency-shell.sh` since
    # it only prints 10 lines.
    curl_common_args+=" --fail"
    if ! curl --head $curl_common_args "${rootfs_url}" >/dev/null; then
        echo "Couldn't query the server for the rootfs specified by:" >&2
        echo "coreos.live.rootfs_url=${rootfs_url}" >&2
        exit 1
    fi

    # bsdtar can read cpio archives and we already depend on it for
    # coreos-liveiso-persist-osmet.service, so use it instead of cpio.
    if ! curl $curl_common_args "${rootfs_url}" | \
            rdcore stream-hash /etc/coreos-live-want-rootfs | \
            bsdtar -xf - -C / ; then
        echo "Couldn't fetch, verify, and unpack image specified by:" >&2
        echo "coreos.live.rootfs_url=${rootfs_url}" >&2
        echo "Check that the URL is correct and that the rootfs version matches the initramfs." >&2
        source /etc/os-release
        if [ -n "${OSTREE_VERSION:-}" ]; then
            echo "The version of this initramfs is ${OSTREE_VERSION}." >&2
        fi
        exit 1
    fi
else
    # Nothing.  Fail.
    echo "No rootfs image found.  Modify your PXE configuration to add the rootfs" >&2
    echo "image as a second initrd, or use the coreos.live.rootfs_url kernel parameter" >&2
    echo "to specify an HTTP or HTTPS URL to the rootfs." >&2
    exit 1
fi
