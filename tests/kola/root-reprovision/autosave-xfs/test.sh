#!/bin/bash
## kola:
##   # This test reprovisions the rootfs automatically.
##   tags: "platform-independent reprovision"
##   # Trigger automatic XFS reprovisioning
##   minDisk: 100
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   description: Verify the root reprovision with XFS 
##     on large disk triggers autosaved.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if [ ! -f /run/ignition-ostree-autosaved-xfs.stamp ]; then
    fatal "expected autosaved XFS"
fi
ok "autosaved XFS on large disk"

eval $(xfs_info / | grep -o 'agcount=[0-9]*')
if [ "$agcount" -gt 4 ]; then
    fatal "expected agcount of at most 4, got ${agcount}"
fi
ok "low agcount on large disk"
