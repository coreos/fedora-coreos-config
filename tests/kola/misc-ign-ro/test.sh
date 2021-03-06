#!/bin/bash
set -xeuo pipefail

ok() {
        echo "ok" "$@"
    }

fatal() {
        echo "$@" >&2
            exit 1
        }

# This test makes sure that swap on zram devices can be set up
# using the zram-generator as defined in the docs at
# https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-configure-swaponzram/

if ! grep -q 'zram0' /proc/swaps; then
    fatal "expected zram0 to be set up"
fi
ok "swap on zram was set up correctly"

# Make sure that coreos-update-ca-trust kicked in and observe the result.
if ! systemctl show coreos-update-ca-trust.service -p ActiveState | grep ActiveState=active; then
    fatal "coreos-update-ca-trust.service not active"
fi
if ! grep '^# coreos.com$' /etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt; then
    fatal "expected coreos.com in ca-bundle"
fi
ok "coreos-update-ca-trust.service"

# Make sure that the stub-resolv.conf file has the correct selinux context.
# https://github.com/fedora-selinux/selinux-policy/pull/509#issuecomment-744540382
# https://github.com/systemd/systemd/pull/17976
context=$(stat --format "%C" /run/systemd/resolve/stub-resolv.conf)
if [ "$context" != "system_u:object_r:net_conf_t:s0" ]; then
    fatal "SELinux context on stub-resolv.conf is wrong"
fi
ok "SELinux context on stub-resolv.conf is correct"

# This is for verifying that `kubernetes_file_t` labeled files can be
# watched by systemd
# See: https://github.com/coreos/fedora-coreos-tracker/issues/861
# See: https://github.com/containers/container-selinux/issues/135
if [ "$(systemctl is-active kube-watch.path)" != "active" ]; then
    fatal "kube-watch.path did not activate successfully"
fi
ok "kube-watch.path successfully activated"

touch /etc/kubernetes/kubeconfig
ok "successfully created /etc/kubernetes/kubeconfig"

if [ "$(systemctl is-active kube-watch.service)" != "active" ]; then
    fatal "kube-watch.service did not successfully activate"
fi
ok "kube-watch.service activated successfully"

if [ "$(journalctl -o cat -u kube-watch.service | sed -n 2p)" != "Found it" ]; then
    fatal "kube-watch.service did not print message to journal"
fi
ok "Found message from kube-watch.service in journal"
