#!/bin/bash
# kola: { "platforms": "qemu-unpriv" }
# This test makes sure that ignition is able to enable systemd units of
# different types.
# https://github.com/coreos/ignition/issues/586
# https://github.com/systemd/systemd/pull/9901
# We don't need to test this on every platform. If it passes in one place it
# will pass everywhere.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# make sure the presets worked and the instantiated unit is enabled
if [ "$(systemctl is-enabled touch@foo.service)" != 'enabled' ]; then
    fatal "touch@foo.service systemd unit should be enabled"
fi
ok "touch@foo.service systemd unit is enabled"

# make sure the unit ran
if ! test -e /run/foo; then
    fatal "touch@foo.service didn't run as /run/foo does not exist"
fi
ok "touch@foo.service ran as /run/foo exists"

if [ "$(systemctl is-enabled podman.socket)" != 'enabled' ]; then
    fatal "podman.socket systemd unit should be enabled"
fi
ok "podman.socket systemd unit is enabled"
