#!/usr/bin/bash
# This script checks if the system is still using cgroups v1
# and prints a message to the serial console.

# Change the output color to yellow
warn=$(echo -e '\033[0;33m')
# No color
nc=$(echo -e '\033[0m')

motd_path=/run/motd.d/30_cgroupsv1_warning.motd

cat << EOF > "${motd_path}"
${warn}
############################################################################
WARNING: This system is using cgroups v1. For increased reliability
it is strongly recommended to migrate this system and your workloads
to use cgroups v2. For instructions on how to adjust kernel arguments
to use cgroups v2, see:
https://docs.fedoraproject.org/en-US/fedora-coreos/kernel-args/

To disable this warning, use:
sudo systemctl disable coreos-check-cgroups.service
############################################################################
${nc}
EOF
