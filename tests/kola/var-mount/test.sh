#!/bin/bash
set -xeuo pipefail

# restrict to qemu for now because the primary disk path is platform-dependent
# kola: {"platforms": "qemu"}

src=$(findmnt -nvr /var -o SOURCE)
[[ $(realpath "$src") == $(realpath /dev/disk/by-partlabel/var) ]]

fstype=$(findmnt -nvr /var -o FSTYPE)
[[ $fstype == xfs ]]
