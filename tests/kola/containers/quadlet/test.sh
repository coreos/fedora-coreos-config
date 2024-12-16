#!/bin/bash
## kola:
##   # We're pulling a container image from Quay.io
##   tags: "platform-independent needs-internet"
##   description: Verify that basic quadlet functionality works.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# Test volume
if ! is_service_active test-volume.service; then
  fatal "test-volume.service failed to start"
fi
volume_info=$(podman volume inspect systemd-test)
if [[ "$(jq -r '.[0].Labels."org.test.Key"' <<< "$volume_info")" != "quadlet-test-volume" ]]; then
    fatal "Volume not correctly created"
fi

# Test network
if ! is_service_active test-network.service; then
  fatal "test-network.service failed to start"
fi
network_info=$(podman network inspect systemd-test)
if [[ "$(jq -r '.[0].labels."org.test.Key"' <<< "$network_info")" != "quadlet-test-network" ]]; then
    fatal "Network not correctly created"
fi

# Test container
if ! is_service_active test.service; then
  fatal "test-network.service failed to start"
fi
container_info=$(podman container inspect systemd-test)
if [[ "$(jq -r '.[0].ImageName' <<< "$container_info")" != "quay.io/fedora/fedora-minimal:latest" ]]; then
    fatal "Container not using the correct image"
fi
if [[ "$(jq -r '.[0].NetworkSettings.Networks[].NetworkID' <<< "$container_info")" != "systemd-test" ]]; then
    fatal "Container not using the correct network"
fi
if [[ "$(jq -r '.[0].HostConfig.Binds[0]' <<< "$container_info")" != "systemd-test:/data:rw,rprivate,nosuid,nodev,rbind" ]]; then
    fatal "Container not using the correct volume"
fi

ok "Successfully tested basic quadlet functionality"
