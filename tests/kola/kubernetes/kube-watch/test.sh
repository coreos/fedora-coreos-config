#!/bin/bash
# kola: { "exclusive": false }
set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

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

# If we check the status too soon it could still be activating..
# Sleep in a loop until it's done "activating"
while [ "$(systemctl is-active kube-watch.service)" == "activating" ]; do
    echo "kube-watch is activating. sleeping for 1 second"
    sleep 1
done
if [ "$(systemctl is-active kube-watch.service)" != "active" ]; then
    fatal "kube-watch.service did not successfully activate"
fi
ok "kube-watch.service activated successfully"

# NOTE: we've observed a race where the journal message shows up as
# coming from `echo` rather than `kube-watch`, so we're embedding
# a UUID in the message to make it easier to find.
if ! journalctl -o cat -b | grep 27a259a8-7f2d-4144-8b8f-23dd201b630c; then
    fatal "kube-watch.service did not print message to journal"
fi
ok "Found message from kube-watch.service in journal"
