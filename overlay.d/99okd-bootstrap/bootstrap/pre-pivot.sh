#!/bin/bash
# This script is invoked by the installer on the bootstrap host
# https://github.com/openshift/installer/blob/master/data/data/bootstrap/files/usr/local/bin/bootstrap-pivot.sh

# Load common functions
. /usr/local/bin/release-image.sh

# Copy manifests
cp /manifests/* /opt/openshift/openshift/ -rvf

# Pivot to new os content
MACHINE_CONFIG_OSCONTENT=$(image_for machine-os-content)
rpm-ostree rebase --experimental "ostree-unverified-registry:${MACHINE_CONFIG_OSCONTENT}"

# Remove mitigations kargs
rpm-ostree kargs --delete mitigations=auto,nosmt

touch /opt/openshift/.pivot-done

systemctl reboot
