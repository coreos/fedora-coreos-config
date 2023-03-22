#!/bin/bash
## kola:
##   tags: "platform-independent needs-internet"
#
# Configure a DHCP linux bridge using butane and nmstate service with policy

set -xeuo pipefail

. $KOLA_EXT_DATA/nmstate-common.sh

main
