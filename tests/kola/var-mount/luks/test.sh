#!/bin/bash
## kola:
##   # Restrict to qemu for now because the primary disk path is platform-dependent
##   platforms: qemu
##   architectures: "! s390x"
##   description: Verify that reprovision disk with luks works.

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# /var

src=$(findmnt -nvr /var -o SOURCE)
[[ $(realpath "$src") == $(realpath /dev/disk/by-partlabel/var) ]]

fstype=$(findmnt -nvr /var -o FSTYPE)
[[ $fstype == xfs ]]

# /var/log

src=$(findmnt -nvr /var/log -o SOURCE)
[[ $(realpath "$src") == $(realpath /dev/mapper/varlog) ]]

blktype=$(lsblk -o TYPE "${src}" --noheadings)
[[ ${blktype} == crypt ]]

fstype=$(findmnt -nvr /var/log -o FSTYPE)
[[ $fstype == ext4 ]]

table=$(dmsetup table varlog)
if grep -q allow_discards <<< "${table}"; then
    fatal "found allow_discards in /var/log DM table: ${table}"
fi
if grep -q no_read_workqueue <<< "${table}"; then
    fatal "found no_read_workqueue in /var/log DM table: ${table}"
fi
ok "discard and custom option not enabled for /var/log"

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      ok "mounted on first boot"

      # reboot once to sanity-check we can mount on second boot
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      ok "mounted on reboot"
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
