#!/bin/bash
set -xeuo pipefail

# Tests that rootless podman containers can DNS resolve external domains.
# https://github.com/coreos/fedora-coreos-tracker/issues/923
# kola: { "tags": "needs-internet", "platforms": "qemu-unpriv", "exclusive": false}

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

runascoreuserscript='
#!/bin/bash
set -euxo pipefail

podman network create testnetwork
podman run --rm -t --network=testnetwork registry.fedoraproject.org/fedora:34 getent hosts google.com
podman network rm testnetwork
'

runascoreuser() {
    # NOTE: If we don't use `| cat` the output won't get copied
    # and won't show up in the output of the ext test.
    sudo -u core "$@" | cat
}

main() {
    echo "$runascoreuserscript" > /tmp/runascoreuserscript
    chmod +x /tmp/runascoreuserscript
    if ! runascoreuser /tmp/runascoreuserscript ; then 
        fatal "DNS in rootless podman testnetwork failed. Test Fails" 
    else 
        ok "DNS in rootless podman testnetwork Suceeded. Test Passes" 
    fi
}

main