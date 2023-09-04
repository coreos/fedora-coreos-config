#!/bin/bash
## kola:
##   # This test reprovisions the rootfs.
##   tags: "platform-independent reprovision"
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # A TPM backend device is not available on s390x to suport TPM.
##   architectures: "! s390x"
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   # Trigger automatic XFS reprovisioning
##   minDisk: 1000
##   description: Verify the root reprovision with XFS and TPM
##     on large disk triggers autosaved.
##     This test is meant to cover ignition-ostree-transposefs-autosave-xfs.service

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# check that we ran automatic XFS reprovisioning
if [ -z "${AUTOPKGTEST_REBOOT_MARK:-}" ]; then
    if [ ! -f /run/ignition-ostree-autosaved-xfs.stamp ]; then
        fatal "expected autosaved XFS"
    fi
    ok "autosaved XFS on large disk"

    eval $(xfs_info / | grep -o 'agcount=[0-9]*')
    expected=4
    if [ "$agcount" -gt "${expected}" ]; then
        fatal "expected agcount of at most ${expected}, got ${agcount}"
    fi
    ok "low agcount on large disk"
fi

# run the rest of the tests
. $KOLA_EXT_DATA/luks-test.sh
