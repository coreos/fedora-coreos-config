#!/bin/bash
## kola:
##   tags: "platform-independent"
##   description: Verify that NetworkManager supports configuring the
##     carrier timeout via the `rd.net.timeout.carrier=` karg.

# Without recreating an environment that requires this setting to be set
# (which would be hard to do), we'll test this by just making sure
# that setting the kernel argument ensures the runtime configuration
# file /run/NetworkManager/conf.d/15-carrier-timeout.conf gets created.
#
# Checking that this file gets created is also tricky because we
# `rm -rf /run/NetworkManager` in coreos-teardown-initramfs on first boot,
# so we'll workaround that by setting the karg permanently and then
# performing a reboot so we can check on the second boot if the file exists.
#
# See:
# - https://bugzilla.redhat.com/show_bug.cgi?id=1917773
# - https://gitlab.freedesktop.org/NetworkManager/NetworkManager/-/commit/e300138892ee0fc3824d38b527b60103a01758ab#

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      ok "first boot"
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      ok "second boot"
      grep rd.net.timeout.carrier=15 /proc/cmdline

      generator_conf="/run/NetworkManager/conf.d/15-carrier-timeout.conf"
      if [ ! -f ${generator_conf} ]; then
        fatal "Error: can not generate ${generator_conf} with karg rd.net.timeout.carrier"
      fi
      ok "NM generated rd.net.timeout.carrier configuration in the initramfs"
      ;;

  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
