#!/bin/bash
set -xeuo pipefail

# No need to run an other platforms than QEMU.
# kola: { "platforms": "qemu-unpriv" }

# We can delete this test when the following issue is resolved:
# https://github.com/coreos/fedora-coreos-tracker/issues/925

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

source /etc/os-release
if [ "$VERSION_ID" -eq "36" ]; then
    if ! grep 'RPM-GPG-KEY-fedora-37' /etc/yum.repos.d/fedora-rawhide.repo; then
        fatal "Fedora 37 gpg key should be in rawhide repo"
    fi
fi
ok rawhiderepo
