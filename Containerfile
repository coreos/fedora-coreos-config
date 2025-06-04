# DO NOT EDIT. This Containerfile is produced by the concatenation of:
# - Containerfile.advisory: contains this advisory
# - Containerfile.args: contains stream-specific build args
# - Containerfile.base: actual build logic
# Rebuild it using `cat Containerfile.* > Containerfile`.

### Containerfile.args

# This is the developer default version. In pipelines, this is driven by versionary.
ARG VERSION="42"
# XXX: This uses the Konflux-built version until it takes over from pungi and
# shows up at the official quay.io/fedora/fedora-bootc endpoint since the latter
# doesn't yet have bootc-base-imagectl.
# https://gitlab.com/fedora/bootc/base-images/-/issues/44
# XXX: Note also this should be a digested pull that gets bumped.
# https://gitlab.com/fedora/bootc/tracker/-/issues/34
ARG BUILDER_IMG=quay.io/bootc-devel/fedora-bootc-42-standard:latest
ARG MANIFEST=manifest.yaml

### Containerfile.base

FROM ${BUILDER_IMG} as builder

ARG VERSION
ARG MANIFEST

# useful if you're hacking on rpm-ostree/bootc-base-imagectl
# COPY rpm-ostree /usr/bin/
# COPY bootc-base-imagectl /usr/libexec/

# Note: once we can rely on https://github.com/coreos/rpm-ostree/pull/5391,
# add this bit to the RUN command to make the developer path less painful.
# --mount=type=cache,rw,id=coreos-build-cache,target=/cache
RUN --mount=type=bind,target=/run/src /run/src/build-rootfs "${MANIFEST}" "${VERSION}" /target-rootfs

FROM scratch
ARG VERSION
COPY --from=builder /target-rootfs/ /
RUN <<EOF
set -xeuo pipefail
for script in /usr/libexec/coreos-postprocess-*; do
  $script; rm $script
done
EOF

LABEL containers.bootc=1
LABEL ostree.bootable=1
LABEL org.opencontainers.image.version=$VERSION
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
