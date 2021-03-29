# This includes the build dependencies for some key packages
# such as ignition, rpm-ostree, libpod, systemd, and kernel.
# If you want another package in this list, submit a PR and
# we can probably add it.
#
# This image is used by CoreOS CI to build software like
# Ignition, rpm-ostree, ostree, coreos-installer, etc...
FROM registry.fedoraproject.org/fedora:33
USER root
WORKDIR /root/containerbuild
COPY . tmp
RUN ./tmp/install-buildroot.sh && yum clean all && rm tmp -rf
WORKDIR /root
# match cosa's unprivileged default
RUN useradd builder --uid 1000 -G wheel && \
        echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/wheel-nopasswd && \
        chmod 600 /etc/sudoers.d/wheel-nopasswd
USER builder
