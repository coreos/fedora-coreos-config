#!/usr/bin/env bash
set -euo pipefail

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

TARGET="/etc/zincati/config.d/00-dummy-placeholder.toml"
OWNER=$(stat -c '%U' "${TARGET}")

# make sure the placeholder file is owned by the proper system user.
if test "${OWNER}" != 'zincati' ; then
    fatal "unexpected owner of ${TARGET}: ${OWNER}"
fi
ok "placeholder file correctly owned by zincati user"
