#!/bin/bash
## kola:
##   exclusive: false
##
## Checks if default shutdown time is 2 mins an 45 seconds
##

# set -xeuo pipefail

# . $KOLA_EXT_DATA/commonlib.sh
source data/commonlib.sh


timeout=$(systemctl show --property=DefaultTimeoutStartUSec | cut -d= -f2)

timeout_seconds=$(echo $timeout | sed -E 's/([0-9]+)min ([0-9]+)s/\1*60+\2/' | bc)
#echo "Timeout is set to $timeout_seconds seconds"

#Verify that the default shutdown time is 2 minutes and 45 seconds (165 seconds)
if [ $timeout_seconds -eq 165 ]; then
  ok "PASS: The default shutdown time is 2 minutes and 45 seconds."
else
  fatal "FAIL: The default shutdown time is not 2 minutes and 45 seconds. This system is $timeout"
fi
