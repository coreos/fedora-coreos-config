#!/bin/bash
# kola: {"platforms": "qemu", "exclusive": false, "distros": "fcos rhcos" }
# Verify the RPM %{vendor} flag for everything installed matches what we expect.
#
# - platforms: qemu
#   - This test should pass everywhere if it passes anywhere.
# - distros: This only handles Fedora and RHEL today.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

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

