#!/usr/bin/env bash
# kola: { "distros": "fcos", "exclusive": false }
# This test only runs on FCOS because `systemd-resolved` is not installed on
# RHCOS

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# Make sure that the stub-resolv.conf file has the correct selinux context.
# https://github.com/fedora-selinux/selinux-policy/pull/509#issuecomment-744540382
# https://github.com/systemd/systemd/pull/17976
context=$(stat --format "%C" /run/systemd/resolve/stub-resolv.conf)
if [ "$context" != "system_u:object_r:net_conf_t:s0" ]; then
    fatal "SELinux context on stub-resolv.conf is wrong"
fi
ok "SELinux context on stub-resolv.conf is correct"
