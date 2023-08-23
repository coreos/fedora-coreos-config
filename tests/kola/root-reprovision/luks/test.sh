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
##   description: Verify the root reprovision with XFS and TPM
##     does not trigger autosaved.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# check that we didn't run automatic XFS reprovisioning
if [ -z "${AUTOPKGTEST_REBOOT_MARK:-}" ]; then
    if [ -f /run/ignition-ostree-autosaved-xfs.stamp ]; then
        fatal "unexpected autosaved XFS"
    fi
    ok "no autosaved XFS on large disk"
fi

# run the rest of the tests
. $KOLA_EXT_DATA/luks-test.sh
