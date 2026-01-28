# To build this, run podman/buildah like this:
#
#     podman build --security-opt=label=disable --cap-add=all --device /dev/fuse \
#         --build-arg-file build-args.conf -v $PWD:/run/src . -t localhost/fedora-coreos
#
# Note: we should be able to drop the `-v $PWD:/run/src` once
# https://github.com/containers/buildah/issues/5952 is fixed.
#
# For development convenience, an `overrides/` directory in the context dir, or
# mounted at `/src/overrides` is supported:
# - The `overrides/rpm` directory can be a yum repo. Its packages take
#   precedence over those from remote repos.
# - The `overrides/rootfs` directory can contain files in a rootfs layout which
#   will be copied on top of the final rootfs.

# Overridden by build-args.conf. The value here is invalid on purpose.
ARG BUILDER_IMG=overridden

FROM ${BUILDER_IMG} as builder

ARG ID=overridden
ARG VERSION=overridden
ARG STREAM=overridden
ARG MUTATE_OS_RELEASE=overridden
ARG MANIFEST=overridden
ARG IMAGE_CONFIG=overridden
# XXX: see inject_passwd_group() in build-rootfs
ARG PASSWD_GROUP_DIR
ARG STRICT_MODE=0

COPY . /src
# canonicalize permission bits, see also https://gitlab.com/fedora/bootc/base-images/-/merge_requests/274
RUN chmod -R a=rX,u+w /src

# this allows FCOS/SCOS/RHCOS to do specific things before going into the shared build-rootfs script
RUN if test -x /src/buildroot-prep; then /src/buildroot-prep; fi

# useful if you're hacking on rpm-ostree/bootc-base-imagectl
# COPY rpm-ostree /usr/bin/
# COPY bootc-base-imagectl /usr/libexec/

# always nuke any leftover libdnf lockfile from interrupted runs
RUN --mount=type=cache,rw,id=coreos-build-cache,target=/cache \
        rm -rf /cache/cache/*lock*
RUN --mount=type=cache,rw,id=coreos-build-cache,target=/cache \
    --mount=type=secret,id=yumrepos,target=/etc/yum.repos.d/secret.repo \
    --mount=type=secret,id=contentsets \
        /src/build-rootfs make-rootfs --target-rootfs /target-rootfs
RUN --mount=type=bind,target=/run/src,rw \
      rpm-ostree experimental compose build-chunked-oci \
        --bootc --format-version=1 --rootfs /target-rootfs \
        --output oci-archive:/run/src/out.ociarchive \
        --label com.coreos.inputhash=$(cat /run/inputhash) \
        --label com.coreos.stream=$STREAM

FROM oci-archive:./out.ociarchive
ARG VERSION
ARG NAME=overridden
ARG DESCRIPTION=overridden
# Need to reference builder here to force ordering. But since we have to run
# something anyway, we might as well cleanup after ourselves.
RUN --mount=type=bind,from=builder,target=/var/tmp \
    --mount=type=bind,target=/run/src,rw \
      rm /run/src/out.ociarchive

LABEL containers.bootc=1 \
      ostree.bootable=1 \
      org.opencontainers.image.version=$VERSION \
      com.coreos.osname=$NAME \
      org.opencontainers.image.title=$DESCRIPTION \
      org.opencontainers.image.description=$DESCRIPTION
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
