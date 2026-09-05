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
##   description: Verify that DNS in rootless podman containers can
##     resolve external domains.

# See https://github.com/coreos/fedora-coreos-tracker/issues/923

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

container=$(get_fedora_minimal_container_ref)
runascoreuserscript="
#!/bin/bash
set -euxo pipefail

podman network create testnetwork
podman run --rm -t --network=testnetwork $container getent hosts google.com
podman network rm testnetwork
"

main() {
    echo "$runascoreuserscript" > /tmp/runascoreuserscript
    chmod +x /tmp/runascoreuserscript
    if ! run_as_core_user /tmp/runascoreuserscript; then
        fatal "DNS in rootless podman testnetwork failed. Test Fails"
    else
        ok "DNS in rootless podman testnetwork succeeded. Test Passes"
    fi
}

main
