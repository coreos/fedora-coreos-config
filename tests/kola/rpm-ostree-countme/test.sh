#!/bin/bash
set -xeuo pipefail

# No need to run an other platforms than QEMU.
# kola: { "tags": "needs-internet", "platforms": "qemu-unpriv" }

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

# Check that the timer got pulled when rpm-ostreed got started
if [[ $(systemctl show -p ActiveState rpm-ostree-countme.timer) != "ActiveState=active" ]] \
	&& [[ $(systemctl show -p SubState rpm-ostree-countme.timer) != "SubState=waiting" ]]; then
	fatal "rpm-ostree-countme timer has not been started"
fi

# Check that running the service manually is successful
systemctl start rpm-ostree-countme.service
if [[ $(systemctl show -p ActiveState rpm-ostree-countme.service) != "ActiveState=inactive" ]] \
	&& [[ $(systemctl show -p SubState rpm-ostree-countme.service) != "SubState=dead" ]] \
	&& [[ $(systemctl show -p Result rpm-ostree-countme.service) != "Result=success" ]] \
	&& [[ $(systemctl show -p ExecMainStatus rpm-ostree-countme.service) != "ExecMainStatus=0" ]]; then
	fatal "rpm-ostree-countme exited with an error"
fi

# Check rpm-ostree count me output
output="$(journalctl --output=json --boot --unit=rpm-ostree-countme.service --grep "Successful requests:" | jq --raw-output '.MESSAGE')"
# depending on the stream, we expect different numbers of countme-enabled repos
if [[ "${output}" != "Successful requests: 1/1" ]] && \
   [[ "${output}" != "Successful requests: 2/2" ]] && \
   [[ "${output}" != "Successful requests: 3/3" ]]; then
	fatal "rpm-ostree-countme service ouput does not match expected sucess output"
fi

ok countme
