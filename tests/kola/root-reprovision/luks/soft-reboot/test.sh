#!/bin/bash
## kola:
##   tags: "platform-independent"
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # A TPM backend device is not available on s390x to support TPM.
##   architectures: "! s390x"
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15
##   creationDate: 2026-06-02
##   description: Verify that soft-reboot works with LUKS root encryption.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

assert_luks_root() {
    local srcdev blktype
    srcdev=$(findmnt -nvr /sysroot -o SOURCE)
    [[ ${srcdev} == /dev/mapper/myluksdev ]]

    blktype=$(lsblk -o TYPE "${srcdev}" --noheadings)
    [[ ${blktype} == crypt ]]
}

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      assert_luks_root
      ok "root is on LUKS device"

      /tmp/autopkgtest-soft-reboot soft-rebooted
      ;;

  soft-rebooted)
      assert_luks_root
      ok "soft-reboot successful with LUKS root"
      ;;

  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
