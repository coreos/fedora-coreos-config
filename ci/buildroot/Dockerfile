# This includes the build dependencies for some key packages
# such as ignition, rpm-ostree, libpod, systemd, and kernel.
# If you want another package in this list, submit a PR and
# we can probably add it.
#
# This image is used by CoreOS CI to build software like
# Ignition, rpm-ostree, ostree, coreos-installer, etc...
FROM quay.io/fedora/fedora:41
# Work around for https://bugzilla.redhat.com/show_bug.cgi?id=2278652
ENV container=oci
COPY . /src
RUN ./src/install-buildroot.sh && yum clean all && rm /src -rf
