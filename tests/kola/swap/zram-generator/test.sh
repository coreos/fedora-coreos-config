#!/bin/bash
# kola: { "distros": "fcos", "exclusive": true}
# This test conflicts with swap/zram-default so we cannot set this to non-exclusive
# This test only runs on FCOS because RHCOS does not have zram support.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# This test makes sure that swap on zram devices can be set up
# using the zram-generator as defined in the docs at
# https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-configure-swaponzram/

if ! grep -q 'zram0' /proc/swaps; then
    fatal "expected zram0 to be set up"
fi
ok "swap on zram was set up correctly"
