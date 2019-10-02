#!/bin/sh
# Script invoked by ignition-dracut generator to detect whether this is a
# live system without a root device.  We can't test for /run/ostree-live
# because it may not have been created yet.
[ -e /root.squashfs ]
