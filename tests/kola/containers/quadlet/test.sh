#!/bin/bash
## kola:
##   # We're pulling a container image from Quay.io
##   tags: "platform-independent needs-internet"
#
# Ensure that basic quadlet functionality works

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if [[ "$(podman volume inspect systemd-test | jq -r '.[0].Labels."org.test.Key"')" != "quadlet-test-volume" ]]; then
    fatal "Volume not correctly created"
fi

if [[ "$(podman network inspect systemd-test | jq -r '.[0].labels."org.test.Key"')" != "quadlet-test-network" ]]; then
    fatal "Network not correctly created"
fi

if [[ "$(podman inspect systemd-test | jq -r '.[0].ImageName')" != "registry.fedoraproject.org/fedora-minimal:latest" ]]; then
    fatal "Container not using the correct image"
fi

if [[ "$(podman inspect systemd-test | jq -r '.[0].NetworkSettings.Networks[].NetworkID')" != "systemd-test" ]]; then
    fatal "Container not using the correct network"
fi

if [[ "$(podman inspect systemd-test | jq -r '.[0].HostConfig.Binds[0]')" != "systemd-test:/data:rw,rprivate,nosuid,nodev,rbind" ]]; then
    fatal "Container not using the correct volume"
fi

ok "Successfully tested basic quadlet functionality"
