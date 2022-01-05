#!/bin/bash
set -xeuo pipefail
# This is to verify udev rules /dev/disk/by-id/scsi-* 
# symlinks present in initramfs
# https://bugzilla.redhat.com/show_bug.cgi?id=1990506

# kola: {"platforms": "qemu", "additionalDisks": ["5G:mpath"]}

. $KOLA_EXT_DATA/commonlib.sh

fstype=$(findmnt -nvr /var -o FSTYPE)
if [ $fstype != xfs ]; then
    fatal "Error: /var fstype is $fstype, expected is xfs"
fi

source /etc/os-release
ostree_conf=""
if [ "$ID" == "fedora" ]; then
    ostree_conf="/boot/loader.1/entries/ostree-1-fedora-coreos.conf"
elif [ "$ID" == "rhcos" ]; then
    ostree_conf="/boot/loader.1/entries/ostree-1-rhcos.conf"
else
    fatal "fail: not operating on expected OS"
fi

initramfs=/boot$(grep initrd ${ostree_conf} | sed 's/initrd //g')
tempfile=$(mktemp)
lsinitrd $initramfs > $tempfile
if ! grep -q "61-scsi-sg3_id.rules" $tempfile; then
    fatal "Error: can not find 61-scsi-sg3_id.rules in $initramfs"
fi

if ! grep -q "63-scsi-sg3_symlink.rules" $tempfile; then
    fatal "Error: can not find 63-scsi-sg3_symlink.rules in $initramfs"
fi

rm -f $tempfile
