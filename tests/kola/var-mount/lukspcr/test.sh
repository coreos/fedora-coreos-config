#!/bin/bash
set -xeuo pipefail

# restrict to qemu for now because the primary disk path is platform-dependent
# kola: {"platforms": "qemu", "architectures": "!s390x"}

. $KOLA_EXT_DATA/commonlib.sh

# /var/publicdata

src=$(findmnt -nvr /var/publicdata -o SOURCE)
[[ $(realpath "$src") == $(realpath /dev/mapper/data) ]]

# we close the drive
umount /var/publicdata
cryptsetup close data

# we validate we can still unlock the drive
clevis luks unlock -d /dev/vda6 -n data
mount /dev/mapper/data /var/publicdata
umount /var/publicdata
cryptsetup close data

# we change the pcr value, that is used to bind the encryption key.
# It will be resetted on reboot.
tpm2_pcrextend 7:sha1=0x1234567890123456789012345678901234567890

# we validate we cannot unbind anymore
if clevis luks unlock -d /dev/vda6 -n data ; then
  fatal "could decrypt the device: the pcr pinning was not applied"
fi

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
