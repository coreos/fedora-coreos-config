#!/bin/bash
## kola:
##   exclusive: false
##   description: Make sure python is only pulled in by nfs-utils
##   distros: fcos

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if vereq "$(get_fedora_ver)" 43; then
    sudo rpm-ostree usroverlay
    sudo rpm -e nfs-utils nfs-utils-coreos python3 python3-libs python-pip-wheel
    ok "no extra pytyhon3 dependencies"
else
    ok "Skipping python3 dependencies test"
    exit 0
fi

