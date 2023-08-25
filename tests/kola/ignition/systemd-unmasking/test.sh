#!/bin/bash
## kola:
##   tags: "platform-independent"
##   # This test is currently scoped to FCOS because `dnsmasq` is not masked on
##   # RHCOS.
##   # TODO-RHCOS: determine if any services on RHCOS are masked and adapt test
##   distros: fcos
##   description: Verify that Ignition supports to unmask units.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# Make sure the systemd unit (dnsmasq) is unmasked and enabled
if [ "$(systemctl is-enabled dnsmasq.service)" != 'enabled' ]; then
    fatal "dnsmasq.service systemd unit should be unmasked and enabled"
fi
ok "dnsmasq.service systemd unit is unmasked and enabled"
