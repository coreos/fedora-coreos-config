#!/bin/bash
# import-virtiofs-systemd-credentials.sh - Import systemd credentials from a virtiofs share
#
# This script scans /sys/fs/virtiofs/*/tag for a virtiofs filesystem tagged
# "io.systemd.credentials". If found, it mounts the filesystem and copies
# credential files into /run/credentials/@system/ where systemd will pick
# them up as system credentials.
#
# virtiofs tag discovery requires kernel >= 6.9 (commit a8f62f50b4e4).
# See https://systemd.io/CREDENTIALS/ for the systemd credentials specification.
# See https://github.com/systemd/systemd/issues/29175 for upstream discussion.

set -euo pipefail

VIRTIOFS_TAG="io.systemd.credentials"
SYSFS_DIR="/sys/fs/virtiofs"
SYSTEMD_CREDS_DIR="" # defined below
MOUNTPOINT="/run/credentials/@virtiofs"

# For EL 9 we need to copy to a different directory because importing
# from /run/credentials/@initrd was only added in systemd v254.
# https://github.com/systemd/systemd/pull/28207
source /etc/os-release
if [ "${PLATFORM_ID:-}" == "platform:el9" ]; then
    SYSTEMD_CREDS_DIR="/run/credstore" # Works with LoadCredential
else
    SYSTEMD_CREDS_DIR="/run/credentials/@initrd"   # Works with ImportCredential
fi

log() {
    echo "import-virtiofs-systemd-credentials: $*" >&2
}

# Check if the virtiofs sysfs directory exists at all. If the virtiofs
# kernel module isn't loaded or no virtiofs devices are present, there's
# nothing to do.
if [ ! -d "${SYSFS_DIR}" ]; then
    log "no virtiofs sysfs directory found, nothing to do"
    exit 0
fi

log "importing into ${SYSTEMD_CREDS_DIR}"

# Scan all virtiofs devices for our well-known tag. The kernel exposes
# virtiofs tags at /sys/fs/virtiofs/<N>/tag (since Linux 6.9).
found=0
for tagfile in "${SYSFS_DIR}"/*/tag; do
    [ -e "${tagfile}" ] || continue
    tag=$(cat "${tagfile}" 2>/dev/null) || continue
    if [ "${tag}" = "${VIRTIOFS_TAG}" ]; then
        found=1
        break
    fi
done

if [ "${found}" -eq 0 ]; then
    log "no virtiofs share with tag '${VIRTIOFS_TAG}' found, nothing to do"
    exit 0
fi

log "found virtiofs share with tag '${VIRTIOFS_TAG}'"

# Create the mountpoint and mount the virtiofs share
mkdir -p "${MOUNTPOINT}"
if ! mount -t virtiofs "${VIRTIOFS_TAG}" "${MOUNTPOINT}"; then
    log "failed to mount virtiofs tag '${VIRTIOFS_TAG}'"
    rmdir "${MOUNTPOINT}" 2>/dev/null || true
    exit 1
fi

# Create the system credentials directory if it doesn't exist.
# This is where systemd looks for system-level credentials.
mkdir -p "${SYSTEMD_CREDS_DIR}"

# Copy each systemd credential file from the virtiofs mount into the systemd
# credentials import initrd directory. Credential names are the filenames.
count=0
for credfile in "${MOUNTPOINT}"/*; do
    [ -f "${credfile}" ] || continue
    credname=$(basename "${credfile}")
    cp "${credfile}" "${SYSTEMD_CREDS_DIR}/${credname}"
    # Credentials should be readable only by root
    chmod 0600 "${SYSTEMD_CREDS_DIR}/${credname}"
    log "imported systemd credential: ${credname}"
    count=$((count + 1))
done

# Clean up the mount
umount "${MOUNTPOINT}"
rmdir "${MOUNTPOINT}" 2>/dev/null || true

log "imported ${count} systemd credential(s)"
