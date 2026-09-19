#!/bin/bash
# Emergency hook: warn that an older coreos-installer may have written
# firstboot network config to /boot, which this image no longer reads.
# In the iSCSI case that missing config prevents the network from
# coming up, which in turn prevents mounting root.

if [ -d /etc/coreos-firstboot-network ] && \
   [ -n "$(ls -A /etc/coreos-firstboot-network 2>/dev/null)" ]; then
    # Config is in the initramfs — this emergency is not caused by
    # misplaced network config.
    return 0
fi

cat <<EOF

------
If you used 'coreos-installer install --copy-network' with an older
version of coreos-installer, the network configuration may have been
written to /boot/coreos-firstboot-network.

This CoreOS image no longer reads firstboot network config from /boot.
The configuration must be embedded in the initramfs.

Re-install using an updated version of coreos-installer.
------

EOF
