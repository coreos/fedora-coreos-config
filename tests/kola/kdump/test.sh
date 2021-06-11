#!/bin/bash
set -xeuo pipefail
# https://docs.fedoraproject.org/en-US/fedora-coreos/debugging-kernel-crashes/
# kola: {"minMemory": 4096, "tags": "skip-base-checks"}

# ===== FIXME: Disabled due to broken CI
echo "Test disabled"
exit 0
# =====

fatal() {
    echo "$@" >&2
    exit 1
}

case "${AUTOPKGTEST_REBOOT_MARK:-}" in
  "")
      rhelver=$(. /etc/os-release && echo ${RHEL_VERSION:-})
      if test -n "${rhelver}"; then
        rhelminor=$(echo "${rhelver}" | cut -f 2 -d '.')
        if test '!' -w /boot && test "${rhelminor}" -lt "5"; then
          mkdir -p /etc/systemd/system/kdump.service.d
          cat > /etc/systemd/system/kdump.service.d/rw.conf << 'EOF'
[Service]
ExecStartPre=mount -o remount,rw /boot
EOF
        fi
      fi
      rpm-ostree kargs --append='crashkernel=300M'
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
