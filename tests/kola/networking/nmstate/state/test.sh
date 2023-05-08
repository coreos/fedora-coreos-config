#!/bin/bash
## kola:
##   tags: "platform-independent needs-internet"
##   description: Verify that configure a DHCP linux bridge using 
##     butane and nmstate service with state works.

# See https://github.com/coreos/fedora-coreos-tracker/issues/1175

set -xeuo pipefail

. $KOLA_EXT_DATA/nmstate-common.sh

main
