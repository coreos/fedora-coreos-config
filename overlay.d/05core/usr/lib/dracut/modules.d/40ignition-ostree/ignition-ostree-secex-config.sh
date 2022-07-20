#!/bin/bash
set -euo pipefail

if [[ -f /run/coreos/secure-execution ]]; then
    bootdev=$(blkid --list-one --output device --match-token PARTLABEL=boot | sed 's,[0-9]\+$,,')
    sed "s,\${BOOTDEV},$bootdev," < /usr/lib/coreos/01-secex.ign > /usr/lib/ignition/base.d/01-secex.ign
fi
