#!/bin/bash
set -euo pipefail

# This is invoked by Dockerfile

dnf -y install dnf-plugins-core
# We want to avoid a 7 day cycle for e.g. new ostree etc.
dnf config-manager setopt updates-testing.enabled=1

dn=$(dirname "$0")
tmpd=$(mktemp -d) && trap 'rm -rf ${tmpd}' EXIT

arch=$(arch)

echo "Installing base build requirements"
dnf -y install /usr/bin/xargs 'dnf-command(builddep)'
deps=$(grep -v '^#' "${dn}"/buildroot-reqs.txt)
if [ -f "${dn}/buildroot-reqs-${arch}.txt" ]; then
  deps+=" "
  deps+=$(grep -v '^#' "${dn}/buildroot-reqs-${arch}.txt")
fi
echo "${deps}" | xargs dnf -y install

echo "Installing build dependencies of primary packages"
brs=$(grep -v '^#' "${dn}"/buildroot-buildreqs.txt)
(cd "${tmpd}" && mkdir rpmbuild
 echo "${brs}" | xargs dnf download --source
 # rebuild the SRPM for this arch; see
 # https://bugzilla.redhat.com/show_bug.cgi?id=1402784#c6
 find . -name '*.src.rpm' -print0 | xargs -0n 1 rpmbuild -rs --nodeps \
    -D "%_topdir $PWD/rpmbuild" -D "%_tmppath %{_topdir}/tmp"
 dnf builddep -y rpmbuild/SRPMS/*.src.rpm)
rm -rf "${tmpd:?}"/*

echo "Installing build dependencies from canonical spec files"
specs=$(grep -v '^#' "${dn}"/buildroot-specs.txt)
(cd "${tmpd}" && echo "${specs}" | xargs curl -L --remote-name-all)
(cd "${tmpd}" && find . -type f -print0 | xargs -0 dnf -y builddep)
rm -rf "${tmpd:?}"/*

echo "Installing test dependencies from canonical upstream files"
testdep_urls=$(grep -v '^#' "${dn}"/testdeps.txt)
(cd "${tmpd}" && echo "${testdep_urls}" | xargs curl -L --remote-name-all)
grep -hrv '^#' "${tmpd}" | xargs dnf -y install
rm -rf "${tmpd:?}"/*

echo 'Done!'
