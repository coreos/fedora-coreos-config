#!/bin/bash
## kola:
##   tags: "platform-independent"
##   # GRUB sugar currently only exists in FCOS
##   distros: fcos
##   # coreos-post-ignition-checks.service forbids GRUB passwords on
##   # ppc64le and s390x
##   architectures: "!ppc64le s390x"
##   description: Verify that setting GRUB password works.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
"")
    # configuration written directly by Ignition
    if ! grep -q '^set superusers="bovik core"$' /boot/grub2/user.cfg; then
        fatal "Missing superusers in GRUB user.cfg"
    fi
    for user in bovik core; do
        if ! grep -q "^password_pbkdf2 $user grub.pbkdf2.sha512.10000." /boot/grub2/user.cfg; then
            fatal "Missing user $user in GRUB user.cfg"
        fi
    done
    ok "Butane GRUB sugar"

    # force a new deployment
    rpm-ostree kargs --append test-added-karg
    /tmp/autopkgtest-reboot rebooted
    ;;
rebooted)
    # check that we booted into the correct deployment
    if ! grep -q test-added-karg /proc/cmdline; then
        fatal "Rebooted into old deployment"
    fi
    # cross-check karg with BLS configs
    if grep -q test-added-karg /boot/loader.0/entries/ostree-1-fedora-coreos.conf; then
        fatal "Old BLS config contains new karg"
    fi
    if ! grep -q test-added-karg /boot/loader.0/entries/ostree-2-fedora-coreos.conf; then
        fatal "New BLS config doesn't contain new karg"
    fi
    # old deployment should require a password to boot
    if ! grep -q '^grub_users ""$' /boot/loader.0/entries/ostree-1-fedora-coreos.conf; then
        fatal "Missing grub_users setting in old BLS config"
    fi
    # new one should not
    if grep -q grub_users /boot/loader.0/entries/ostree-2-fedora-coreos.conf; then
        fatal "grub_users setting present in new BLS config"
    fi
    ok "BLS grub_users setting"
    ;;
*)
    fatal "Unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}"
    ;;
esac
