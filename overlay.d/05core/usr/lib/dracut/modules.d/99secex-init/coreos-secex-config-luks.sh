#!/bin/bash
set -euo pipefail

# after reencryption have to set the description again
cryptsetup token add --key-description secex:boot -S 0 /dev/disk/by-label/crypt_bootfs
cryptsetup token add --key-description secex:root -S 0 /dev/disk/by-label/crypt_rootfs

# prevent systemd-cryptsetup-generator from opening the volumes
uuid_root=$(cryptsetup luksUUID /dev/disk/by-label/crypt_bootfs)
uuid_boot=$(cryptsetup luksUUID /dev/disk/by-label/crypt_rootfs)
cat > /sysroot/etc/crypttab <<EOF
crypt_rootfs UUID=${uuid_root} none noauto
crypt_bootfs UUID=${uuid_boot} none noauto
EOF
