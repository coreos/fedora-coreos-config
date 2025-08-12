# To build this, run podman/buildah like this:
#
#     podman build --security-opt=label=disable --cap-add=all --device /dev/fuse \
#         --build-arg-file build-args.conf -v $PWD:/run/src . -t localhost/fedora-coreos
#
# Note: we should be able to drop the `-v $PWD:/run/src` once
# https://github.com/containers/buildah/issues/5952 is fixed.

# Overridden by build-args.conf. The value here is invalid on purpose.
ARG BUILDER_IMG=overridden

FROM ${BUILDER_IMG} as builder

ARG VERSION=overridden
ARG MANIFEST=overridden
# XXX: see inject_passwd_group() in build-rootfs
ARG PASSWD_GROUP_DIR

# useful if you're hacking on rpm-ostree/bootc-base-imagectl
# COPY rpm-ostree /usr/bin/
# COPY bootc-base-imagectl /usr/libexec/

# always nuke any leftover libdnf lockfile from interrupted runs
RUN --mount=type=cache,rw,id=coreos-build-cache,target=/cache \
        rm -rf /cache/cache/*lock*
RUN --mount=type=cache,rw,id=coreos-build-cache,target=/cache \
    --mount=type=secret,id=yumrepos,target=/etc/yum.repos.d/secret.repo \
    --mount=type=secret,id=contentsets \
    --mount=type=bind,target=/run/src \
        /run/src/build-rootfs "${MANIFEST}" "${VERSION}" /target-rootfs
RUN --mount=type=bind,target=/run/src,rw \
      rpm-ostree experimental compose build-chunked-oci \
        --bootc --format-version=1 --rootfs /target-rootfs \
        --output oci-archive:/run/src/out.ociarchive

FROM oci-archive:./out.ociarchive
ARG VERSION
ARG NAME=overridden
# Need to reference builder here to force ordering. But since we have to run
# something anyway, we might as well cleanup after ourselves.
RUN --mount=type=bind,from=builder,target=/var/tmp \
    --mount=type=bind,target=/run/src,rw \
      rm /run/src/out.ociarchive

LABEL containers.bootc=1
LABEL ostree.bootable=1
LABEL org.opencontainers.image.version=$VERSION
LABEL com.coreos.osname=$NAME
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
