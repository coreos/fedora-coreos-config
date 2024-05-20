#!/bin/bash
## kola:
##   # Testing kdump requires some reserved memory for the crashkernel.
##   minMemory: 4096
##   # Skip checks for things like kernel crashes in the console logs.
##   # For this test we trigger a kernel crash on purpose.
##   tags: skip-base-checks
##   # This test includes a few reboots and the generation of a vmcore,
##   # which can take longer than the default 10 minute timeout.
##   timeoutMin: 15
##   description: Verify that the crashkernel reserved memory is large enough.

# See https://docs.fedoraproject.org/en-US/fedora-coreos/debugging-kernel-crashes/

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      # use 120s for this since kdump can take a while to build its initramfs,
      # especially if the system is loaded
      if ! is_service_active kdump.service 120; then
          fatal "kdump.service failed to start"
      fi
      # Verify that the crashkernel reserved memory is large enough
      output=$(kdumpctl estimate)
      if grep -q "WARNING: Current crashkernel size is lower than recommended size" <<< "$output"; then
          fatal "The reserved crashkernel size is lower than recommended."
      fi
      /tmp/autopkgtest-reboot-prepare aftercrash
      # Add in a sleep to workaround race condition where XFS/kernel errors happen
      # during crash kernel boot.
      # https://github.com/coreos/fedora-coreos-tracker/issues/1195
      sleep 5
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
