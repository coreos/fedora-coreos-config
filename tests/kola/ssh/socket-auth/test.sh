#!/bin/bash
## kola:
##   distros: fcos
##   tags: platform-independent
##   creationDate: 2026-07-20
##   description: Verify that Ignition-provided SSH keys work
##     with socket-activated sshd.
##   timeoutMin: 5

# This test masks sshd.service and enables sshd.socket using butane,
# which forces kola to connect through the socket-activated path.
#
# See https://github.com/coreos/fedora-coreos-tracker/issues/2098
#
# The primary check here is implicit on whether the SSH connection to
# the kola VM succeeds at all, but some additional sanity checks are
# also included below.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if systemctl is-active sshd.service 2> /dev/null; then
    fatal "sshd.service is active; expected only sshd.socket"
fi
ok "sshd.service is not active"

if ! systemctl is-active sshd.socket 2> /dev/null; then
    systemctl status sshd.socket
    fatal "sshd.socket is not active"
fi
ok "sshd.socket is active"

ok "SSH authentication works via socket-activated sshd"
