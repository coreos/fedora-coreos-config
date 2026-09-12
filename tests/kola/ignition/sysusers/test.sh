#!/usr/bin/env bash
## kola:
##   platforms: qemu
##   description: Verify file ownership can reference system users.

set -xeuo pipefail

. "$KOLA_EXT_DATA/commonlib.sh"

TARGET="/etc/dnsmasq/config.d/00-dummy-placeholder.toml"
OWNER=$(stat -c '%U' "${TARGET}")

# make sure the placeholder file is owned by the proper system user.
if test "${OWNER}" != 'dnsmasq' ; then
    fatal "unexpected owner of ${TARGET}: ${OWNER}"
fi
ok "placeholder file correctly owned by dnsmasq user"
