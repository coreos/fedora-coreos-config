#!/bin/bash
set -euo pipefail

# Link session so cryptsetup later can open volumes
# https://github.com/systemd/systemd/issues/5522
keyctl link @us @s

cryptsetup open /dev/disk/by-label/crypt_rootfs crypt_rootfs
cryptsetup open /dev/disk/by-label/crypt_bootfs crypt_bootfs
