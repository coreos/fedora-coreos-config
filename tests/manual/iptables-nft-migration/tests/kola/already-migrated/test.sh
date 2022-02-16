#!/bin/bash
set -xeuo pipefail

# kola: { "tags": "needs-internet" }

. $KOLA_EXT_DATA/common.sh

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      assert_iptables_nft
      assert_iptables_differs_from_default
      upgrade
      /tmp/autopkgtest-reboot rebooted
      ;;

  rebooted)
      assert_iptables_nft
      assert_iptables_matches_default
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
