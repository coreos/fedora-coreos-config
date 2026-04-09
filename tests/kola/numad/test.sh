#!/bin/bash
## kola:
##   platforms: qemu
##   numaNodes: true
##   minMemory: 2048
##   architectures: "!s390x"
##   description: Verify that numad detects nodes and tracks set -euo pipefail
##   bindMountHostRO: ["/,/var/cosaroot"]
##   creationDate: 2026-04-09

set -euo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if [[ $(systemctl show numad -p ActiveState) != "ActiveState=active" ]]; then
    fatal "numad did not activate"
fi

# Call numad to change the already running daemon's settings for -l and -i
# `-l 7` adds extra information to the logs
# `-i 5` changes interval from every 15s to every 5s
numad -l7 -i5

if ! lscpu | grep -Eq "NUMA node\(s\):\s*2"; then
    fatal "expected to find exactly 2 numa nodes"
fi

# As part of the test we want to run a somewhat intensive process, so that
# we can verify that numad is successfully tracking processes. Here we
# use the same pattern of using a mounted in COSA as the container root as:
# https://github.com/coreos/coreos-assembler/blob/8dbfe3ea8b8f571e732e8cc0ab307e983a0be1f3/mantle/cmd/kola/resources/iscsi_butane_setup.yaml#L102-L113
podman run --privileged --name stress-ng --pid=host                      \
    --volume=root:/root/:nocopy --volume=vartmp:/var/tmp/:nocopy         \
    --workdir /root --rootfs /var/cosaroot                               \
    stress-ng --temp-path /var/tmp --vm 1 --vm-bytes 1024M --timeout 25s

logfile="/var/log/numad.log"
for node in 0 1; do
	# Different versions of numad have a slightly different format for the log file,
	# e.g. MBs_total vs MBs_tot. This pattern should match both versions.
	if ! grep -Eq "Node.${node}.*MBs_tot(al)?.*CPUs_tot(al)?" "$logfile"; then
		fatal "Numad didn't detect Node ${node}"
	fi
done

# Check that the stress test was being monitored by numad
if ! grep -q "stress-ng-vm" "$logfile"; then
    fatal "Numad is not monitoring the stress test"
fi

ok "Numad working as expected"
