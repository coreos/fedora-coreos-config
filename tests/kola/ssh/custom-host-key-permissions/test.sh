#!/bin/bash
## kola:
##   tags: platform-independent
##   description: Verify that sshd still works with a custom 
##     host key with mode 640 and group ssh_keys.

# See
# - https://github.com/coreos/fedora-coreos-tracker/issues/1394
# - https://src.fedoraproject.org/rpms/openssh/pull-request/37

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# recent Fedora sshd binaries will fail to start if all configured host keys
# have mode > 600 and their modes haven't automatically been fixed
# that part is implicitly tested by kola, which needs sshd to connect

# make sure our key was actually used
# grep -q causes sshd -T to fail on SIGPIPE
if ! sshd -T | grep "^hostkey /etc/ssh-host-key$" >/dev/null; then
    sshd -T
    fatal "configured host key not used by sshd"
fi
ok "configured host key used by sshd"

# sshd starts successfully if any keys are mode 600, which would invalidate
# the test except that our HostKey directive should replace the default
# keys.  verify this.
if [[ $(sshd -T | grep "^hostkey " | wc -l) != 1 ]]; then
    sshd -T | grep "^hostkey "
    fatal "sshd uses multiple host keys"
fi
ok "sshd uses only the configured host key"
