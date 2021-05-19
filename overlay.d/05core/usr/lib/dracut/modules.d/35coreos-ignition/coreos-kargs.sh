#!/bin/bash
set -euo pipefail

/usr/bin/rdcore kargs --boot-device /dev/disk/by-label/boot --create-if-changed /run/ignition-modified-kargs "$@"
