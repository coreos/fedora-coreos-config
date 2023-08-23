#!/bin/bash
## kola:
##   exclusive: false
##   description: Verify that `kubernetes_file_t` labeled files can be read 
##     by systemd, also verify the `kube-env` service started successfully  
##     and the service wrote to the journal successfully.

# See https://bugzilla.redhat.com/show_bug.cgi?id=1973418

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

if [ "$( stat -c %C /etc/kubernetes/envfile)" != "system_u:object_r:kubernetes_file_t:s0" ]; then
    fatal "/etc/kubernetes/envfile is labeled incorrectly"
fi
ok "/etc/kubernetes/envfile is labeled correctly"

if [ "$(systemctl is-failed kube-env.service)" != "active" ]; then
    fatal "kube-env.service failed unexpectedly"
fi
ok "kube-env.service successfully started"

# Verify that 'FCOS' was wrtitten to the journal
if ! journalctl -o cat -u kube-env.service | grep FCOS; then
    fatal "kube-env.service did not write 'FCOS' to journal"
fi
ok "kube-env.service ran and wrote 'FCOS' to the journal"
