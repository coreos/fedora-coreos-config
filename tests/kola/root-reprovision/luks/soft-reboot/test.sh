#!/bin/bash
## kola:
##   # This test reprovisions the rootfs.
##   tags: "platform-independent reprovision"
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # A TPM backend device is not available on s390x to support TPM.
##   architectures: "! s390x"
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   description: Verify that soft-reboot works with LUKS root encryption.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      srcdev=$(findmnt -nvr /sysroot -o SOURCE)
      [[ ${srcdev} == /dev/mapper/myluksdev ]]

      blktype=$(lsblk -o TYPE "${srcdev}" --noheadings)
      [[ ${blktype} == crypt ]]
      ok "root is on LUKS device"

      # Workaround: manually add x-initrd.attach to crypttab if not
      # already present. This can be removed once coreos/ignition#2219
      # is included in the base image.
      if ! grep -q x-initrd.attach /etc/crypttab; then
          sed -i '/^myluksdev /s/$/,x-initrd.attach/' /etc/crypttab
          systemctl daemon-reload
      fi

      /tmp/autopkgtest-soft-reboot soft-rebooted
      ;;

  soft-rebooted)
      srcdev=$(findmnt -nvr /sysroot -o SOURCE)
      [[ ${srcdev} == /dev/mapper/myluksdev ]]

      blktype=$(lsblk -o TYPE "${srcdev}" --noheadings)
      [[ ${blktype} == crypt ]]
      ok "soft-reboot successful with LUKS root"
      ;;

  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
