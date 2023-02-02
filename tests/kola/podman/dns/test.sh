#!/bin/bash
## kola:
##   # This test pulls a container from a registry.
##   tags: "platform-independent needs-internet"
##   # This test doesn't make meaningful changes to the system and
##   # should be able to be combined with other tests.
##   exclusive: false
##   # This test reaches out to the internet and it could take more
##   # time to pull down the container.
##   timeoutMin: 3
#
# Tests that rootless podman containers can DNS resolve external domains.
# https://github.com/coreos/fedora-coreos-tracker/issues/923

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

runascoreuserscript='
#!/bin/bash
set -euxo pipefail

podman network create testnetwork
podman run --rm -t --network=testnetwork registry.fedoraproject.org/fedora:37 getent hosts google.com
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
