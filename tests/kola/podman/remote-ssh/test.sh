#!/bin/bash
## kola:
##   tags: platform-independent
##   exclusive: true
##   creationDate: 2026-09-02
##   description: Verify that podman-remote can connect to the podman
##     socket via SSH.
#
# This test catches SELinux regressions where sshd_session_t is
# denied connectto on container_runtime_t:unix_stream_socket.
#
# See:
# - https://github.com/coreos/fedora-coreos-tracker/issues/2217
# - https://github.com/fedora-selinux/selinux-policy/issues/3392

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# Private key, root authorized_keys, and podman.socket are provisioned via config.bu
run_as_core_user podman system connection add --identity /home/core/.ssh/test_key con1 root@localhost
if ! run_as_core_user podman --connection con1 info; then
    ausearch -m avc -ts recent || true
    fatal "podman-remote SSH connection to localhost failed"
fi
ok "podman-remote SSH connection to localhost succeeded"
