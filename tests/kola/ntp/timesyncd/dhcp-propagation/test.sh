#!/bin/bash
## kola:
##   # Add the needs-internet tag. This test builds a container from remote
##   # sources and uses a remote NTP server.
##   tags: "needs-internet"
##   # Limit to qemu because some cloud providers have their own special
##   # sauce for NTP/chrony and we don't want to interfere with that.
##   platforms: qemu
##   # Pulling and building the container can take a long time if a
##   # slow mirror gets chosen. Bump the timeout to 15 minutes
##   timeoutMin: 15
##   # There's a bug in dnf that is causing OOM on low memory systems:
##   # https://bugzilla.redhat.com/show_bug.cgi?id=1907030
##   # https://pagure.io/releng/issue/10935#comment-808601
##   minMemory: 1536
##   # We only care about timesyncd in Fedora. It's not available elsewhere.
##   distros: fcos
##   description: Verify that timesyncd service got ntp servers from DHCP.
#
# This script creates two veth interfaces i.e. one for the host machine
# and other for the container(dnsmasq server). This setup will be helpful
# to verify the DHCP propagation of NTP servers. This will also avoid any
# regression that might cause in RHCOS or FCOS when the upstream changes
# come down and obsolete the temporary work (https://github.com/coreos/fedora-coreos-config/pull/412)

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"
. $KOLA_EXT_DATA/ntplib.sh

main() {

    # Choose a host from https://tf.nist.gov/tf-cgi/servers.cgi
    # that can get DNS over DNSSEC since the environment our OpenShift
    # runs in requires DNSSEC validation. Test with https://dnsviz.net/
    ntp_host_ip=$(getent hosts utcnist.colorado.edu | cut -d ' ' -f 1)

    ntp_test_setup $ntp_host_ip

    check_for_ntp_server $ntp_host_ip "timedatectl show-timesync -p ServerAddress --value"

    ok "timesyncd got ntp servers from DHCP"
}

main
