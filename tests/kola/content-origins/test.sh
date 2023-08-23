#!/bin/bash
## kola:
##   tags: "platform-independent"
##   # This is a read-only, nondestructive test.
##   exclusive: false
##   # May support e.g. centos in the future
##   distros: "fcos rhcos"
##   description: Verify the RPM %{vendor} flag for everything installed
##     matches what we expect.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

. /usr/lib/os-release

case "${ID}" in
    fedora) vendor='Fedora Project';;
    rhel|rhcos) vendor='Red Hat, Inc.';;
    *) echo "Unknown operating system ID=${ID}; skipping this test"; exit 0;;
esac

cd $(mktemp -d)
rpm -qa --queryformat='%{name},%{vendor}\n' > rpmvendors.txt
if grep -vF ",${vendor}" rpmvendors.txt > unmatched.txt; then
    cat unmatched.txt
    fatal "Expected only vendor ${vendor} for all packages"
fi
echo "ok all RPMs produced by Vendor: ${vendor}"

