#!/bin/bash
## kola:
##   description: Verify that network-online.target doesn't block login
##   tags: platform-independent
##   # this really shouldn't take long; if it does, it's that we're hitting the
##   # very issue we're testing for
##   timeoutMin: 3

# If the user provides a systemd unit which pulls in `network-online.target`,
# we want to make sure that logins don't block on `network-online.target` being
# reached. `block-network-online.service` verifies this by pulling in `network-
# online.target` and preventing it from being reached by running `Before=` it
# and sleeping forever.

# We hit this in RHCOS with iscsi.service causing network-online.target to block
# remote-fs-pre.target and hence systemd-user-sessions.service from running:
#
# https://github.com/openshift/os/pull/1279
# https://issues.redhat.com/browse/OCPBUGS-11124

set -euo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# The fact that we're here means that `systemd-user-sessions.service` was
# reached and logins work since kola was able to SSH to start us. But let's do
# some sanity-checks to verify that the test was valid.

# verify that block-network-online.service is still activating since it's stuck sleeping
if [[ $(systemctl show block-network-online -p ActiveState) != "ActiveState=activating" ]]; then
  systemctl status block-network-online.service
  fatal "block-network-online.service isn't activating"
fi

# verify that network-online.target is not yet active since it's still blocked on block-network-online.service
if [[ $(systemctl show network-online.target -p ActiveState) != "ActiveState=inactive" ]]; then
  systemctl status network-online.target
  fatal "network-online.target isn't inactive"
fi

echo "ok network-online.target does not block login"
