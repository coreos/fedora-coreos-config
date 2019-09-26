#!/bin/bash
set -euo pipefail

# Today this is trivial, but in the future this will require integration
# with Ignition.
mountflags=prjquota
mount -o "${mountflags}" /dev/disk/by-label/root /sysroot
