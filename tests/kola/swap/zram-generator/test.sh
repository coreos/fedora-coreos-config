#!/bin/bash
## kola:
##   # This test only runs on FCOS because RHCOS does not have zram support.
##   distros: fcos
##   # This test conflicts with swap/zram-default so we cannot set this to non-exclusive
##   exclusive: true
##   description: Verify that swap on zram devices can be set up using the 
##     zram-generator as defined.

# See docs at https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-configure-swaponzram/

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if ! grep -q 'zram0' /proc/swaps; then
    fatal "expected zram0 to be set up"
fi
ok "swap on zram was set up correctly"
