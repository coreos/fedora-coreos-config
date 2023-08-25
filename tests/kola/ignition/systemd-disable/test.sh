#!/bin/bash
## kola:
##   tags: "platform-independent"
##   # This test is currently scoped to FCOS because `zincati` is only available
##   # on FCOS.
##   # TODO-RHCOS: Determine if any services on RHCOS may be disabled and adapt test
##   distros: fcos
##   description: Verify that Ignition supports to disable units.

# See https://github.com/coreos/fedora-coreos-tracker/issues/392

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if [ "$(systemctl is-enabled zincati.service)" != 'disabled' ]; then
    fatal "zincati.service systemd unit should be disabled"
fi
ok "zincati.service systemd unit is enabled"
