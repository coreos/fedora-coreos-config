#!/bin/bash
# See coreos-post-ignition-checks.service for more information about this script
set -euo pipefail

# Verify that GRUB password directives are only used when GRUB is being used
arch=$(uname -p)
# Butane sugar will tell ignition to mount /boot to /sysroot/boot. We can simply check if
# the file exists to see whether the check needs to be performed.
# It is possible that the user creates a config, which will mount /boot at a different path
# but that case is not officially supported.
if [ -f /sysroot/boot/grub2/user.cfg ]; then
    # s390x does not use GRUB, ppcle64 uses petitboot with a GRUB config parser which does not support passwords
    # So in both these cases, GRUB password is not supported
    if grep -q password_pbkdf2 /sysroot/boot/grub2/user.cfg && [[ "$arch" =~ ^(s390x|ppc64le)$ ]]; then
        echo "Ignition config provisioned a GRUB password, which is not supported on $arch"
        exit 1
    fi
fi
