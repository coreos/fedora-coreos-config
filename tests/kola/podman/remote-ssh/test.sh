#!/bin/bash
## kola:
##   tags: platform-independent
##   exclusive: true
##   creationDate: 2026-09-29
##   description: Verify that podman-remote can connect to the podman
##     socket via SSH.
#
# This test catches SELinux regressions where sshd_session_t is
# denied connectto on container_runtime_t:unix_stream_socket.
#
# See:
# - https://github.com/coreos/fedora-coreos-tracker/issues/2217
# - https://github.com/fedora-selinux/selinux-policy/issues/3392
#
# Private key, authorized_keys, and podman.socket for both rootless and rootful checks
# are provisioned via config.bu.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# ROOTLESS
run_as_core_user systemctl --user enable --now podman.socket
run_as_core_user podman system connection add --identity /home/core/.ssh/test_key con-rootless core@localhost
if ! run_as_core_user podman --connection con-rootless info; then
    ausearch -m avc -ts recent || true
    fatal "podman-remote SSH connection to localhost as core failed"
fi
ok "podman-remote SSH connection to localhost as core succeeded"

# ROOTFUL (FCOS only)
# On RHCOS/SCOS, sshd refuses root login by default:
# https://github.com/coreos/rhel-coreos-config/blob/main/overlay.d/05rhcos/etc/ssh/sshd_config.d/40-rhcos-defaults.conf
if is_fcos; then
    run_as_core_user podman system connection add --identity /home/core/.ssh/test_key con-root root@localhost
    if ! run_as_core_user podman --connection con-root info; then
        ausearch -m avc -ts recent || true
        fatal "podman-remote SSH connection to localhost as root failed"
    fi
    ok "podman-remote SSH connection to localhost as root succeeded"
fi
