#!/usr/bin/bash
# Install 68-azure-sriov-nm-unmanaged.rules into the initramfs

# called by dracut
check() {
    return 0
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    inst_rules 68-azure-sriov-nm-unmanaged.rules
}
