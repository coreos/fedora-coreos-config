#!/bin/bash
set -xeuo pipefail

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

#Testing that a user password provisioned by ignition works
OUTPUT=$(echo 'foobar' | setsid su - tester -c id)

if [[ $OUTPUT != "uid=1001(tester) gid=1001(tester) groups=1001(tester) context=system_u:system_r:unconfined_service_t:s0" ]]; then
    fatal "Failure when checking command output running with specified username and password"
fi
# yescrypt was changed to the default in Fedora 35
# https://fedoraproject.org/wiki/Changes/yescrypt_as_default_hashing_method_for_shadow
# Testing that passwd command creates a yescrypt password hash(starting with '$y$')
source /etc/os-release 
if [ "$VERSION_ID" -ge "35" ]; then
    sudo useradd tester2
    echo "42abcdef" | sudo passwd tester2 --stdin
    PASSWD_CONFIRMATION=$(sudo grep tester2 /etc/shadow)
    if [[ ${PASSWD_CONFIRMATION:0:11} != 'tester2:$y$' ]]; then
        fatal "passwd did not create a yescrypt password hash"
    fi
fi
ok "User-password provisioned and passwd command successfully tested"