#!/bin/bash
# kola: { "platforms": "qemu-unpriv", "allowConfigWarnings": true }
# - platforms: qemu-unpriv 
#   - This test should pass everywhere if it passes anywhere. 
# - allowConfigWarnings: true 
#   - We intentionally exclude the Install section from a systemd unit.  
#     This is valid but not ideal, so Butane warns about it.  
# This test ensures that Ignition warnings are displayed on the console.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

WARN='\033[0;33m' # yellow
RESET='\033[0m' # reset

warningsfile="/etc/issue.d/30_coreos_ignition_warnings.issue"
tmpd=$(mktemp -d)
expectedwarningsfile="${tmpd}"/expectedwarningsfile

# Check for the motd file
if ! test -f ${warningsfile}; then
    fatal "not found Ignition warnings issue file"
fi

echo -e "${WARN}Ignition: warning at $.systemd.units.0.contents: unit \"echo.service\" is enabled, but has no install section so enable does nothing${RESET}" > $expectedwarningsfile

if ! diff $expectedwarningsfile $warningsfile; then
    fatal "Ignition warning did not show up as expected in issue.d"
fi
ok "Successfully displayed Ignition warning on the console"
