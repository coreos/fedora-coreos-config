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

need_restart='false'

# delete the disabling of updates that was done by the test framework
if [ -f /etc/zincati/config.d/90-disable-auto-updates.toml ]; then
    rm -f /etc/zincati/config.d/90-disable-auto-updates.toml
    need_restart='true'
fi

# Early `next` releases before [1] had auto-updates disabled too. Let's
# drop that config if it exists.
# [1] https://github.com/coreos/fedora-coreos-config/commit/99eab318998441760cca224544fc713651f7a16d
if [ -f /etc/zincati/config.d/90-disable-on-non-production-stream.toml ]; then
    rm -f /etc/zincati/config.d/90-disable-on-non-production-stream.toml
    need_restart='true'
fi

get_booted_deployment_json() {
    rpm-ostree status  --json | jq -r '.deployments[] | select(.booted == true)'
}
version=$(get_booted_deployment_json | jq -r '.version')
stream=$(get_booted_deployment_json | jq -r '.["base-commit-meta"]["fedora-coreos.stream"]')

# Pick up the last release for the current stream from the update server
test -f /srv/updateinfo.json || \
    curl -L "https://updates.coreos.fedoraproject.org/v1/graph?basearch=$(arch)&stream=${stream}&rollout_wariness=0" > /srv/updateinfo.json
last_release=$(jq -r .nodes[-1].version /srv/updateinfo.json)
last_release_index=$(jq '.nodes | length-1' /srv/updateinfo.json)
latest_edge=$(jq -r .edges[0][1] /srv/updateinfo.json)

# Now that we have the release from update json, let's check if it has an edge pointing to it
# The latest_edge would ideally have the value of last_release_index if the release has rolled out
# If the edge does not exist, we would pick the second last release as our last_release
if [ $last_release_index != $latest_edge ]; then
    last_release=$(jq -r .nodes[-2].version /srv/updateinfo.json)
fi

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
        file="/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${ver}-primary"
        if [ ! -e $file ]; then
            need_restart='true'
            curl -L "https://src.fedoraproject.org/rpms/fedora-repos/raw/rawhide/f/RPM-GPG-KEY-fedora-${ver}-primary" | \
                sudo tee $file
            sudo chcon -v --reference="/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${VERSION_ID}-primary" $file
        fi
    done
}

fix-update-url() {
    # We switched to non stg URL in zincati v0.0.10 [1]. For older clients
    # we need to update the runtime configuration of zincati to get past the problem.
    # [1] https://github.com/coreos/zincati/commit/1d73801ccd015cdce89f082cb1eeb9b4b8335760
    file='/etc/zincati/config.d/50-fedora-coreos-cincinnati.toml'
    if [ ! -e $file ]; then
        need_restart='true'
        cat > $file <<'EOF'
[cincinnati]
base_url= "https://updates.coreos.fedoraproject.org"
EOF
    fi
}

fix-allow-downgrade() {
    # Older FCOS will complain about an upgrade target being 'chronologically older than current'
    # This is documented in https://github.com/coreos/fedora-coreos-tracker/issues/481
    # We can workaround the problem via a config dropin:
    file='/etc/zincati/config.d/99-fedora-coreos-allow-downgrade.toml'
    if [ ! -e $file ]; then
        need_restart='true'
        cat > $file <<'EOF'
updates.allow_downgrade = true
EOF
    fi
}

move-to-cgroups-v2() {
    # When upgrading to latest F41+ the system won't even boot on cgroups v1
    if grep -q unified_cgroup_hierarchy /proc/cmdline; then
        systemctl stop zincati
        rpm-ostree cancel
        rpm-ostree kargs --delete=systemd.unified_cgroup_hierarchy
        need_restart='true'
    fi
}

# A helper to wait for the fix-selinux-labels script to finish
wait-for-coreos-fix-selinux-labels() {
    # First make sure the migrations/fix script has finished (if it is going
    # to run) before doing the checks
    systemd-run --wait --property=After=coreos-fix-selinux-labels.service \
        echo "Waited for coreos-fix-selinux-labels.service to finish"
}

selinux-sanity-check() {
    # First make sure the migrations/fix script has finished if this is the boot
    # where the fixes are taking place.
    wait-for-coreos-fix-selinux-labels
    # Verify SELinux labels are sane. Migration scripts should have cleaned
    # up https://github.com/coreos/fedora-coreos-tracker/issues/1772
    unlabeled="$(find /sysroot -context '*unlabeled_t*' -print0 | xargs --null -I{} ls -ldZ '{}')"
    if [ -n "${unlabeled}" ]; then
        fatal "Some unlabeled files were found"
    fi
    mislabeled="$(restorecon -vnr /var/ /etc/ /usr/ /boot/)"
    if [ -n "${mislabeled}" ]; then
        # Exceptions for files that could be wrong (sometimes upgrades are messy)
        # - Would relabel /var/lib/cni from system_u:object_r:var_lib_t:s0 to system_u:object_r:container_var_lib_t:s0
        # - Would relabel /etc/selinux/targeted/semanage.read.LOCK from system_u:object_r:semanage_trans_lock_t:s0 to system_u:object_r:selinux_config_t:s0
        # - Would relabel /etc/selinux/targeted/semanage.trans.LOCK from system_u:object_r:semanage_trans_lock_t:s0 to system_u:object_r:selinux_config_t:s0
        # - Would relabel /etc/systemd/journald.conf.d from system_u:object_r:etc_t:s0 to system_u:object_r:systemd_conf_t:s0
        # - Would relabel /etc/systemd/journald.conf.d/forward-to-console.conf from system_u:object_r:etc_t:s0 to system_u:object_r:systemd_conf_t:s0
        # - Would relabel /boot/lost+found from system_u:object_r:unlabeled_t:s0 to system_u:object_r:lost_found_t:s0' ']'
        # - Would relabel /var/lib/systemd/home from system_u:object_r:init_var_lib_t:s0 to system_u:object_r:systemd_homed_library_dir_t:s0
        #       - 39.20230916.1.1->41.20240928.10.1
        #       - https://github.com/fedora-selinux/selinux-policy/commit/3ba70ae27d067f7edc0a52ff722511c5ada724f2
        # - Would relabel /var/cache/systemd from system_u:object_r:var_t:s0 to system_u:object_r:systemd_cache_t:s0
        #   Would relabel /var/cache/systemd/home from system_u:object_r:var_t:s0 to system_u:object_r:systemd_homed_cache_t:s0
        #       - 38.20230322.1.0->42.20241023.91.0
        #       - https://github.com/fedora-selinux/selinux-policy/commit/b08568ca696f14d3232adef6a291ebb0ec80ba46
        #       - https://github.com/coreos/fedora-coreos-tracker/issues/1819
        declare -A exceptions=(
           ['/var/lib/cni']=1
           ['/etc/selinux/targeted/semanage.read.LOCK']=1
           ['/etc/selinux/targeted/semanage.trans.LOCK']=1
           ['/etc/systemd/journald.conf.d']=1
           ['/etc/systemd/journald.conf.d/forward-to-console.conf']=1
           ['/boot/lost+found']=1
           ['/var/lib/systemd/home']=1
           ['/var/cache/systemd']=1
           ['/var/cache/systemd/home']=1
        )
        paths="$(echo "${mislabeled}" | grep "Would relabel" | cut -d ' ' -f 3)"
        found=""
        while read -r path; do
            # Add in a few temporary glob exceptions
            # https://github.com/coreos/fedora-coreos-tracker/issues/1806
            [[ "${path}" =~ /etc/selinux/targeted/active/ ]] && continue
            # https://github.com/coreos/fedora-coreos-tracker/issues/1808
            [[ "${path}" =~ /boot/ostree/.*/dtb ]] && continue
            if [[ "${exceptions[$path]:-noexception}" == 'noexception' ]]; then
                echo "Unexpected mislabeled file found: ${path}"
                found="1"
            fi
        done <<< "${paths}"
        if [ "${found}" == "1" ];then
            fatal "Some unexpected mislabeled files were found."
        fi
    fi
    ok "Selinux sanity checks passed"
}

ok "Reached version: $version"

# Are we all the way at the desired target version?
# If so then we can exit with success!
if vereq $version $target_version; then
    ok "Fully upgraded to $target_version"
    # log bootupctl information for inspection and check the status output
    state=$(/usr/bin/bootupctl status 2>&1)
    echo "$state"
    if ! echo "$state" | grep -q "CoreOS aleph version"; then
        fatal "check bootupctl status output"
    fi
    # One last check!
    selinux-sanity-check
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
        verlt $version '34.20210413.1.0' && move-to-cgroups-v2
        verlt $version '32.20200517.1.0' && fix-allow-downgrade
        verlt $version '32.20200505.1.0' && fix-update-url
        ;;
    'testing')
        verlt $version '35.20211119.2.0' && grab-gpg-keys
        verlt $version '34.20210529.2.0' && move-to-cgroups-v2
        verlt $version '31.20200517.2.0' && fix-allow-downgrade
        verlt $version '31.20200505.2.0' && fix-update-url
        ;;
    'stable')
        verlt $version '35.20211119.3.0' && grab-gpg-keys
        verlt $version '34.20210529.3.0' && move-to-cgroups-v2
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
    # In case the SELinux fix script is running this boot let's wait for it to
    # finish before initiating an `rpm-ostree rebase` so we aren't writing at the
    # same time it's fixing.
    wait-for-coreos-fix-selinux-labels
    rpm-ostree rebase "fedora-compose:fedora/$(arch)/coreos/${target_stream}" $target_version
    /tmp/autopkgtest-reboot $version # execute the reboot
    sleep infinity
fi

# Restart if configuration was changed
if [ "${need_restart}" == "true" ]; then
    /tmp/autopkgtest-reboot setup
    sleep infinity
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


# OK update has been initiated, prepare for reboot and loop to show
# status of zincati and rpm-ostreed
/tmp/autopkgtest-reboot-prepare $version
while true; do
    sleep 20
    systemctl status rpm-ostreed zincati --lines=0
done
