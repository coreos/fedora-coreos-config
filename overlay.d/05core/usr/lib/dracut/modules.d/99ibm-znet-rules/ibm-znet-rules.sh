#!/bin/bash
set -euo pipefail

# Fix for https://bugzilla.redhat.com/show_bug.cgi?id=1818033

znet=$(lszdev qeth -c ID --no-headings | awk -F ":" '{print $1}')
for dev in ${znet}; do
    # chzdev creates udev rules to store the persistent configuration of devices in this directory. File names start with "41-".
    rule="/sysroot/etc/udev/rules.d/41-qeth-${dev}.rules"
    if [[ ! -f ${rule} ]]; then
	echo "${dev}: generating ${rule}"
	chzdev qeth -e ${dev} --no-root-update --base /etc=/sysroot/etc
    fi
done
