#!/bin/bash
set -euo pipefail

# This is invoked by Dockerfile

dn=$(dirname "$0")
tmpd=$(mktemp -d) && trap 'rm -rf ${tmpd}' EXIT

echo "Installing base build requirements"
dnf -y install /usr/bin/xargs 'dnf-command(builddep)'
deps=$(grep -v '^#' "${dn}"/buildroot-reqs.txt)
echo "${deps}" | xargs dnf -y install

echo "Installing build dependencies of primary packages"
brs=$(grep -v '^#' "${dn}"/buildroot-buildreqs.txt)
echo "${brs}" | xargs dnf -y builddep

echo "Installing build dependencies from canonical spec files"
specs=$(grep -v '^#' "${dn}"/buildroot-specs.txt)
(cd "${tmpd}" && echo "${specs}" | xargs curl -L --remote-name-all)
(cd "${tmpd}" && find . -type f -print0 | xargs -0 dnf -y builddep --spec)
rm -rf "${tmpd:?}"/*

echo "Installing test dependencies from canonical upstream files"
testdep_urls=$(grep -v '^#' "${dn}"/testdeps.txt)
(cd "${tmpd}" && echo "${testdep_urls}" | xargs curl -L --remote-name-all)
grep -hrv '^#' "${tmpd}" | xargs dnf -y install
rm -rf "${tmpd:?}"/*

echo 'Done!'
