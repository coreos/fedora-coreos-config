#!/bin/bash
set -xeuo pipefail

# kola: { "platforms": "qemu", "tags": "needs-internet", "exclusive": false, "timeoutMin": 3 }
# Tests that rootless podman containers can DNS resolve external domains.
# https://github.com/coreos/fedora-coreos-tracker/issues/923
#
# - platforms: qemu
#   - This test should pass everywhere if it passes anywhere.
# - tags: needs-internet
#   - This test pulls a container from a registry.
# - exclusive: false
#   - This test doesn't make meaningful changes to the system and
#     should be able to be combined with other tests.
#   - Root reprovisioning requires at least 4GiB of memory.
# - timeoutMin: 3
#   - This test reaches out to the internet and it could take more
#     time to pull down the container.

. $KOLA_EXT_DATA/commonlib.sh

runascoreuserscript='
#!/bin/bash
set -euxo pipefail

podman network create testnetwork
podman run --rm -t --network=testnetwork registry.fedoraproject.org/fedora:35 getent hosts google.com
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
