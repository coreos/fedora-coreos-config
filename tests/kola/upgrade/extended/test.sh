#!/bin/bash
## kola:
##   # - needs-internet: to pull updates
##   tags: "needs-internet"
##   # Extend the timeout since a lot of updates/reboots can happen.
##   timeoutMin: 45
##   # Only run this test when specifically requested.
##   requiredTag: extended-upgrade
##   description: Verify upgrade works.

set -eux -o pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# This test will attempt to test an upgrade from a given starting
# point (assumed by the caller passing in a specific
# `cosa kola run --build=x.y.z`) all the way to the latest build
# that is staged to be released. The test is basic in that it
# essentially tests 1) updates work 2) boot works.
#
# An example invocation for this test would look like:

# ```
# cosa buildfetch --stream=next --build=34.20210904.1.0 --artifact=qemu
# cosa decompress --build=34.20210904.1.0
# cosa kola run --build=34.20210904.1.0 --tag extended-upgrade
# ```
#
# You can monitor the progress from the console and journal:
#   - everything:
#       - tail -f tmp/kola/ext.config.upgrade.extended/*/console.txt
#   - major events:
#       - tail -f tmp/kola/ext.config.upgrade.extended/*/journal.txt | grep --color -i 'ok reached version'
#
# For convenience, here is a list of the earliest releases on each
# stream/architecture. x86_64 minimum version has to be 32.x because
# of https://github.com/coreos/fedora-coreos-tracker/issues/1448
#
# stable
#   - x86_64  31.20200108.3.0 -> works for BIOS, not UEFI
#             32.20200601.3.0
#   - aarch64 34.20210821.3.0
#   - s390x   36.20220618.3.1
# testing
#   - x86_64  32.20200601.2.1
#   - aarch64 34.20210904.2.0
#   - s390x   36.20220618.2.0
# next
#   - x86_64  32.20200416.1.0
#   - aarch64 34.20210904.1.0
#   - s390x   36.20220618.1.1

. /etc/os-release # for $VERSION_ID

need_zincati_restart='false'

# delete the disabling of updates that was done by the test framework
if [ -f /etc/zincati/config.d/90-disable-auto-updates.toml ]; then
    rm -f /etc/zincati/config.d/90-disable-auto-updates.toml
    need_zincati_restart='true'
fi

# Early `next` releases before [1] had auto-updates disabled too. Let's
# drop that config if it exists.
# [1] https://github.com/coreos/fedora-coreos-config/commit/99eab318998441760cca224544fc713651f7a16d
if [ -f /etc/zincati/config.d/90-disable-on-non-production-stream.toml ]; then
    rm -f /etc/zincati/config.d/90-disable-on-non-production-stream.toml
    need_zincati_restart='true'
fi

get_booted_deployment_json() {
    rpm-ostree status  --json | jq -r '.deployments[] | select(.booted == true)'
}
version=$(get_booted_deployment_json | jq -r '.version')
stream=$(get_booted_deployment_json | jq -r '.["base-commit-meta"]["fedora-coreos.stream"]')

# Pick up the last release for the current stream
test -f /srv/releases.json || \
    curl -L "https://builds.coreos.fedoraproject.org/prod/streams/${stream}/releases.json" > /srv/releases.json
last_release=$(jq -r .releases[-1].version /srv/releases.json)

# If the user dropped down a /etc/target_stream file then we'll
# pick up the info from there.
target_stream=$stream
test -f /etc/target_stream && target_stream=$(< /etc/target_stream)
test -f /srv/builds.json || \
    curl -L "https://builds.coreos.fedoraproject.org/prod/streams/${target_stream}/builds/builds.json" > /srv/builds.json
target_version=$(jq -r .builds[0].id /srv/builds.json)


grab-gpg-keys() {
    # For older FCOS we had an issue where when we tried to pull the
    # commits from the repo it would fail if we were on N-2 because
    # the newer commits would be signed with a key the old OS didn't
    # know anything about. We applied a workaround in newer releases,
    # so this workaround should be limited to zincati older than v0.0.24
    # https://github.com/coreos/fedora-coreos-tracker/issues/749
    max_version=${target_version:0:2} # i.e. 36, 37, 38, etc..
    for ver in $(seq $VERSION_ID $max_version); do
        test -e "/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${ver}-primary" && continue
        curl -L "https://src.fedoraproject.org/rpms/fedora-repos/raw/rawhide/f/RPM-GPG-KEY-fedora-${ver}-primary" | \
            sudo tee "/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${ver}-primary"
        sudo chcon -v --reference="/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${VERSION_ID}-primary" "/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${ver}-primary"
    done
    # restart Zincati in case the process had been kicked off earlier
    # than this script ran.
    need_zincati_restart='true'
}

fix-update-url() {
    # We switched to non stg URL in zincati v0.0.10 [1]. For older clients
    # we need to update the runtime configuration of zincati to get past the problem.
    # [1] https://github.com/coreos/zincati/commit/1d73801ccd015cdce89f082cb1eeb9b4b8335760
    cat <<'EOF' > /run/zincati/config.d/50-fedora-coreos-cincinnati.toml
[cincinnati]
base_url= "https://updates.coreos.fedoraproject.org"
EOF
    need_zincati_restart='true'
}

fix-allow-downgrade() {
    # Older FCOS will complain about an upgrade target being 'chronologically older than current'
    # This is documented in https://github.com/coreos/fedora-coreos-tracker/issues/481
    # We can workaround the problem via a config dropin:
    cat <<'EOF' > /run/zincati/config.d/99-fedora-coreos-allow-downgrade.toml
updates.allow_downgrade = true
EOF
    need_zincati_restart='true'
}

ok "Reached version: $version"

# Are we all the way at the desired target version?
# If so then we can exit with success!
if vereq $version $target_version; then
    ok "Fully upgraded to $target_version"
    # log bootupctl information for inspection where available
    [ -f /usr/bin/bootupctl ] && /usr/bin/bootupctl status
    exit 0
fi

# Apply workarounds based on the current version of the system.
#
# First release on each stream with new enough zincati for updates stg.fedoraproject.org
# - 31.20200505.3.0
# - 31.20200505.2.0
# - 32.20200505.1.0
#
# First release with new enough zincati with workaround for N-2 gpg key issue
# - 35.20211119.3.0
# - 35.20211119.2.0
# - 35.20211119.1.0
#
# First release with new enough rpm-ostree with fix for allow-downgrade issue
# - 31.20200517.3.0
# - 31.20200517.2.0
# - 32.20200517.1.0
#
case "$stream" in
    'next')
        verlt $version '35.20211119.1.0' && grab-gpg-keys
        verlt $version '32.20200517.1.0' && fix-allow-downgrade
        verlt $version '32.20200505.1.0' && fix-update-url
        ;;
    'testing')
        verlt $version '35.20211119.2.0' && grab-gpg-keys
        verlt $version '31.20200517.2.0' && fix-allow-downgrade
        verlt $version '31.20200505.2.0' && fix-update-url
        ;;
    'stable')
        verlt $version '35.20211119.3.0' && grab-gpg-keys
        verlt $version '31.20200517.3.0' && fix-allow-downgrade
        verlt $version '31.20200505.3.0' && fix-update-url
        ;;
    *) fatal "unexpected stream: $stream";;
esac

# If we have made it all the way to the last release then
# we have one more test. We'll now rebase to the target
# version, which should be in the compose OSTree repo.
if vereq $version $last_release; then
    systemctl stop zincati
    rpm-ostree rebase "fedora-compose:fedora/$(arch)/coreos/${target_stream}" $target_version
    /tmp/autopkgtest-reboot reboot # execute the reboot
    sleep infinity
fi

# Restart Zincati if configuration was changed
if [ "${need_zincati_restart}" == "true" ]; then
    rpm-ostree cancel # in case anything was already in progress
    systemctl restart zincati
fi

# Watch the Zincati logs to see if it got a lead on a new update.
# Timeout after some time if no update. Unset pipefail since the
# journalctl -f will give a bad exit code when grep exits early.
set +o pipefail
cmd="journalctl -b 0 -f --no-tail -u zincati.service"
if ! timeout 90s $cmd | grep --max-count=1 'proceeding to stage it'; then
    # No update initiated within timeout; let's error.
    fatal "Updating the system stalled out on version: $version"
fi
set -o pipefail


# OK update has been initiated, prepare for reboot and sleep
/tmp/autopkgtest-reboot-prepare reboot
sleep infinity
