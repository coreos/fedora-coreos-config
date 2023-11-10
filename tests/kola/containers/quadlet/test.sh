#!/bin/bash
## kola:
##   # We're pulling a container image from Quay.io
##   tags: "platform-independent needs-internet"
##   description: Verify that basic quadlet functionality works.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if [[ "$(podman volume inspect systemd-test | jq -r '.[0].Labels."org.test.Key"')" != "quadlet-test-volume" ]]; then
    fatal "Volume not correctly created"
fi

if [[ "$(podman network inspect systemd-test | jq -r '.[0].labels."org.test.Key"')" != "quadlet-test-network" ]]; then
    fatal "Network not correctly created"
fi

if [[ "$(podman inspect systemd-test | jq -r '.[0].ImageName')" != "quay.io/fedora/fedora-minimal:39" ]]; then
    fatal "Container not using the correct image"
fi

if [[ "$(podman inspect systemd-test | jq -r '.[0].NetworkSettings.Networks[].NetworkID')" != "systemd-test" ]]; then
    fatal "Container not using the correct network"
fi

if [[ "$(podman inspect systemd-test | jq -r '.[0].HostConfig.Binds[0]')" != "systemd-test:/data:rw,rprivate,nosuid,nodev,rbind" ]]; then
    fatal "Container not using the correct volume"
fi

ok "Successfully tested basic quadlet functionality"
