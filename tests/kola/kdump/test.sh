#!/bin/bash
set -xeuo pipefail
# https://docs.fedoraproject.org/en-US/fedora-coreos/debugging-kernel-crashes/
# Only run on QEMU x86_64 for now:
# https://github.com/coreos/fedora-coreos-tracker/issues/860
# kola: {"platforms": "qemu-unpriv", "minMemory": 4096, "tags": "skip-base-checks", "architectures": "x86_64"}

fatal() {
    echo "$@" >&2
    exit 1
}

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      rpm-ostree kargs --append='crashkernel=256M'
      systemctl enable kdump.service
      /tmp/autopkgtest-reboot setcrashkernel
      ;;
  setcrashkernel)
      /tmp/autopkgtest-reboot-prepare aftercrash
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
      info=$(file ${kcore})
      if ! [[ "${info}" =~ 'vmcore: Kdump'.*'system Linux' ]]; then
        fatal "vmcore does not appear to be a Kdump?"
      fi
      ;;
  *) fatal "unexpected mark: ${AUTOPKGTEST_REBOOT_MARK}";;
esac
