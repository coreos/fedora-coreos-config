#!/bin/bash
set -euo pipefail

dn=$(dirname "$0")

# This is invoked by Dockerfile

echo "Installing base build requirements"
dnf -y install /usr/bin/xargs 'dnf-command(builddep)'
deps=$(grep -v '^#' "${dn}"/buildroot-reqs.txt)
echo "${deps}" | xargs dnf -y install

echo "Installing build dependencies of primary packages"
brs=$(grep -v '^#' "${dn}"/buildroot-buildreqs.txt)
echo "${brs}" | xargs dnf -y builddep

echo "Installing build dependencies from canonical spec files"
specs=$(grep -v '^#' "${dn}"/buildroot-specs.txt)
tmpd=$(mktemp -d) && trap 'rm -rf ${tmpd}' EXIT
(cd "${tmpd}" && echo "${specs}" | xargs curl -L --remote-name-all)
(cd "${tmpd}" && find . -type f -print0 | xargs -0 dnf -y builddep --spec)

echo 'Done!'
