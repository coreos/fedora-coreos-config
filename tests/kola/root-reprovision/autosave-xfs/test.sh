#!/bin/bash
## kola:
##   # This test reprovisions the rootfs automatically.
##   tags: "platform-independent reprovision"
##   # Trigger automatic XFS reprovisioning (heuristic)
##   minDisk: 1000
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   description: Verify the root reprovision with XFS
##     on large disk triggers autosaved.
##     This test is meant to cover ignition-ostree-transposefs-autosave-xfs.service

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if [ ! -f /run/ignition-ostree-autosaved-xfs.stamp ]; then
    fatal "expected autosaved XFS"
fi
# Verify we printed something about the agcount
journalctl -u ignition-ostree-transposefs-autosave-xfs.service --grep=agcount
ok "autosaved XFS on large disk"

eval $(xfs_info /sysroot | grep -o 'agcount=[0-9]*')
expected=4
if [ "$agcount" -gt "$expected" ]; then
    fatal "expected agcount of at most ${expected}, got ${agcount}"
fi
ok "low agcount on large disk"
