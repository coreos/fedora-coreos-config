#!/bin/bash
# kola: { "exclusive": false }
# This is for verifying that `kubernetes_file_t` labeled files can be
# watched by systemd
# See: https://github.com/coreos/fedora-coreos-tracker/issues/861
# See: https://github.com/containers/container-selinux/issues/135

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if [ "$(systemctl is-active kube-watch.path)" != "active" ]; then
    fatal "kube-watch.path did not activate successfully"
fi
ok "kube-watch.path successfully activated"

touch /etc/kubernetes/kubeconfig
ok "successfully created /etc/kubernetes/kubeconfig"

# Give the service 30 seconds to activate
active=0
for i in {1..30}; do
    if systemctl is-active kube-watch.service; then
        active=1
        break
    fi
    sleep 1
done
if [[ $active != 1 ]]; then
    systemctl status kube-watch.service
    fatal "kube-watch.service did not successfully activate"
fi
ok "kube-watch.service activated successfully"

if ! test -e /var/tmp/kube-watched; then
    fatal "/var/tmp/kube-watched does not exist"
fi
ok "/var/tmp/kube-watched exists"
