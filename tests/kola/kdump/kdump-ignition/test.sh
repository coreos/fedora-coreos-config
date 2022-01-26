#!/bin/bash

set -xeuo pipefail
 
fatal() {
    echo "$@" >&2
    exit 1
}
 
case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      # check kdump service
      # TODO
      /tmp/autopkgtest-reboot-prepare aftercrash
      # trigger kdump
      echo "Triggering sysrq"
      sync
      echo 1 > /proc/sys/kernel/sysrq
      # This one will trigger kdump, which will write the kernel core, then reboot.
      echo c > /proc/sysrq-trigger
      # We shouldn't reach this point
      sleep 5
      fatal "failed to invoke sysrq"
      ;;
 
  aftercrash)
      kcore=$(find /var/crash -type f -name vmcore)
      if test -z "${kcore}"; then
        fatal "No kcore found in /var/crash"
      fi
      info=$(file "${kcore}")
      if ! [[ "${info}" =~ 'vmcore: Kdump'.*'system Linux' ]]; then
        fatal "vmcore does not appear to be a Kdump?"
      fi
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac