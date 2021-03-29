#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

depends() {
    echo ignition
}

install() {
    mkdir -p "$initdir/usr/lib/ignition/base.d"
    mkdir -p "$initdir/usr/lib/ignition/base.platform.d"

    # Common entries
    inst "$moddir/30-afterburn-sshkeys-core.ign" \
        "/usr/lib/ignition/base.d/30-afterburn-sshkeys-core.ign"

    # Platform specific: aws
    mkdir -p "$initdir/usr/lib/ignition/base.platform.d/aws"
    inst "$moddir/20-aws-nm-cloud-setup.ign" \
        "/usr/lib/ignition/base.platform.d/aws/20-aws-nm-cloud-setup.ign"

    # Platform specific: azure
    mkdir -p "$initdir/usr/lib/ignition/base.platform.d/azure"
    inst "$moddir/20-azure-nm-cloud-setup.ign" \
        "/usr/lib/ignition/base.platform.d/azure/20-azure-nm-cloud-setup.ign"

    # Platform specific: gcp
    mkdir -p "$initdir/usr/lib/ignition/base.platform.d/gcp"
    inst "$moddir/20-gcp-nm-cloud-setup.ign" \
        "/usr/lib/ignition/base.platform.d/gcp/20-gcp-nm-cloud-setup.ign"
}
