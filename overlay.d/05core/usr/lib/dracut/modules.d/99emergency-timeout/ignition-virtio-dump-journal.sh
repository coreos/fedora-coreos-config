#!/bin/bash
set -euo pipefail

port=/dev/virtio-ports/com.coreos.ignition.journal
if [ -e "${port}" ]; then
    # Sync to backing filesystem before dumping what's there
    journalctl --sync
    journalctl -o json > "${port}"
    # And this signals end of stream
    echo '{}' > "${port}"
else
    echo "Didn't find virtio port ${port}"
fi
