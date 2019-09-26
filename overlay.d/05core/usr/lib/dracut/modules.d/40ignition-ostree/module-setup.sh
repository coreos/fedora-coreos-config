#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

depends() {
    echo ignition
}

install_ignition_unit() {
    local unit=$1; shift
    local target=${1:-complete}
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    local targetpath="$systemdsystemunitdir/ignition-${target}.target.requires/"
    mkdir -p "${initdir}/${targetpath}"
    ln_r "../$unit" "${targetpath}/${unit}"
}

install() {
    inst_multiple \
        realpath \
        setfiles \
        systemd-sysusers \
        systemd-tmpfiles \
        sort \
        uniq

    # coreos-growpart deps
    inst_multiple \
        basename  \
        blkid     \
        cat       \
        dirname   \
        findmnt   \
        growpart  \
        realpath  \
        resize2fs \
        tail      \
        touch     \
        xfs_growfs

    # growpart deps
    # Mostly generated from the following command:
    # 	$ bash --rpm-requires /usr/bin/growpart | sort | uniq | grep executable
    # with a few false positives (rq, rqe, -v) and one missed (mktemp)
    inst_multiple \
	awk       \
	cat       \
	dd        \
	grep      \
	mktemp    \
	partx     \
	rm        \
	sed       \
	sfdisk    \
	sgdisk

    for x in mount populate; do
        install_ignition_unit ignition-ostree-${x}-var.service
        inst_script "$moddir/ignition-ostree-${x}-var.sh" "/usr/sbin/ignition-ostree-${x}-var"
    done

    inst_simple \
        /usr/lib/udev/rules.d/90-coreos-device-mapper.rules

    inst_simple "$moddir/multipath-generator" \
        "$systemdutildir/system-generators/multipath-generator"

    inst_multiple jq chattr getfattr lsmod dd modprobe
    inst_script "$moddir/ignition-ostree-dracut-rootfs.sh" "/usr/libexec/ignition-ostree-dracut-rootfs"
    for x in detect save restore; do
        install_ignition_unit ignition-ostree-rootfs-${x}.service
    done

    # Disk support
    install_ignition_unit ignition-ostree-mount-firstboot-sysroot.service diskful
    install_ignition_unit ignition-ostree-mount-subsequent-sysroot.service diskful-subsequent
    inst_script "$moddir/ignition-ostree-mount-sysroot.sh" \
        "/usr/sbin/ignition-ostree-mount-sysroot"

    install_ignition_unit ignition-ostree-growfs.service
    inst_script "$moddir/coreos-growpart" /usr/libexec/coreos-growpart

    inst_script "$moddir/coreos-relabel" /usr/bin/coreos-relabel
}
