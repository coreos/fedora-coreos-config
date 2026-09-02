#!/bin/bash
## kola:
##   tags: platform-independent
##   creationDate: 2026-09-02
##   description: Verify that specifying an unresolved symlink for the homeDir
##                field does not lead to a relabelling issue.
#
# This test checks for a regression in our path-handling with the homeDir field.
# Ignition should resolve the user-given homeDir to prevent the node
# from failing to provision.
#
# See https://github.com/coreos/fedora-coreos-tracker/issues/2216
#
# The primary check here is implicit on whether the node is successfully
# provisioned at all, but some additional sanity checks are also included below.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if ! id -u core; then
    fatal "no core user"
fi
if [[ ! -L /home ]]; then
    fatal "/home not a symlink"
fi
if [[ ! -d /home/core ]]; then
    fatal "/home/core not a directory"
fi
ok "homeDir handles unresolved symlinks"
