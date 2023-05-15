#!/bin/bash
## kola:
##   tags: needs-internet
##   description: Verify Ignition supports remote config.

# See https://bugzilla.redhat.com/show_bug.cgi?id=1980679
# remote.ign is on github, inject kernelArguments and write 
# something to /etc/testfile.
# config.ign is to include remote kargsfile.ign.


set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

if ! grep -q foobar /proc/cmdline; then
    fatal "missing foobar in kernel cmdline"
else
    ok "find foobar in kernel cmdline"
fi
if ! test -e /etc/testfile; then
    fatal "not found /etc/testfile"
else
    ok "find expected file /etc/testfile"
fi
ok "Ignition remote config test"
