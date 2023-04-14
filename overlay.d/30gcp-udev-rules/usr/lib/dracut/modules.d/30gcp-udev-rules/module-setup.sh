#!/usr/bin/bash
# Install 64-gce-disk-removal.rules, 65-gce-disk-naming.rules and
# google_nvme_id into the initramfs

# called by dracut
install() {
    inst_simple /usr/lib/udev/google_nvme_id
    inst_multiple \
        /usr/lib/udev/rules.d/64-gce-disk-removal.rules \
        /usr/lib/udev/rules.d/65-gce-disk-naming.rules
}
