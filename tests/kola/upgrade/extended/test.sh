#!/bin/bash
## kola:
##   # - needs-internet: to pull updates
##   tags: "needs-internet"
##   # Extend the timeout since a lot of updates/reboots can happen.
##   timeoutMin: 75
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
arch=$(arch)

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

booted_deployment_json=$(rpm-ostree status  --json | \
                         jq -r '.deployments[] | select(.booted == true)')
version=$(jq -r '.version' <<< "${booted_deployment_json}")
stream=$(jq -r '.["base-commit-meta"]["fedora-coreos.stream"]' <<< "${booted_deployment_json}")
if [ "$stream" == "null" ]; then
    # On a container based deployment we don't have the fedora coreos stream
    # in the same place it used to be. Try to grab it from the new place.
    ostree_manifest=$(jq -r '.["base-commit-meta"]["ostree.manifest"]' <<< "${booted_deployment_json}")
    stream=$(jq -r '.annotations | .["fedora-coreos.stream"]' <<< "${ostree_manifest}")
fi

# Pick up the last release for the current stream from the update server
test -f /srv/updateinfo.json || \
    curl -L "https://updates.coreos.fedoraproject.org/v1/graph?basearch=${arch}&stream=${stream}&rollout_wariness=0&oci=true" > /srv/updateinfo.json
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

selinux-sanity-check() {
    # Drop the rollback deployment. In the case where the name of a
    # label gets changed then the rollback deployment will show files
    # as unlabeled_t because the currently loaded policy (i.e. the upgraded
    # policy) doesn't know about the old label. Since we are more concerned
    # about the upgraded system let's just focus on finding unlabeled files
    # there and drop the rollback deployment.
    # https://github.com/coreos/fedora-coreos-tracker/issues/2007#issuecomment-3197248482
    echo "Dropping rollback deployment"
    rpm-ostree cleanup --rollback
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
        # - Would relabel /var/lib/systemd/random-seed from system_u:object_r:init_var_lib_t:s0 to system_u:object_r:random_seed_t:s0
        #       - 42.20250526.1.0 -> 42.20250609.1.0
        #       - https://github.com/coreos/fedora-coreos-tracker/issues/1965#issuecomment-2959831808
        # - Would relabel /var/opt/kola* from unconfined_u:object_r:var_t:s0 to unconfined_u:object_r:usr_t:s0
        #       - 42.20250410.2.0 -> 43.20251031.20.0
        #       - https://github.com/coreos/fedora-coreos-tracker/issues/2052#issuecomment-3474594545
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
           ['/var/lib/systemd/random-seed']=1
           ['/var/opt/kola']=1
           ['/var/opt/kola/extdata']=1
           ['/var/opt/kola/extdata/commonlib.sh']=1
        )
        paths="$(echo "${mislabeled}" | grep "Would relabel" | cut -d ' ' -f 3)"
        found=""
        while read -r path; do
            # Add in a glob exception for /usr/etc/systemd/system for <F43 releases
            # https://github.com/coreos/fedora-coreos-tracker/issues/2030#issuecomment-3329932294
            if [[ "${path}" =~ /usr/etc/systemd/system ]] && [ "$(get_fedora_ver)" -eq 42 ]; then
                 continue
             fi
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

verify-alternatives-migration() {
    # Do verification only if version is 43 or later.
    if [ "$(get_fedora_ver)" -le 43 ]; then
        ok "Skipping alternatives migration verfication for versions before 43"
        return 0
    fi

    # Verify /var/lib/alternatives dir is removed
    if [[ -e /var/lib/alternatives ]]; then
        fatal "Error: migration didn't remove /var/lib/alternatives"
    fi

    # Verify iptables migration
    if [[ $(alternatives --display iptables | grep -c -E 'link currently points to /usr/(bin|sbin)/iptables-nft') != "1" ]]; then
        fatal "Error: migration did not set iptables to nft backend"
    fi
    if [[ $(iptables --version | grep -c "nf_tables") != "1" ]]; then
        fatal "Error: iptables not reset to nftables backend"
    fi

    ok "alternatives migration verification passed."
}

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
    # One more last check
    verify-alternatives-migration
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

# First, since coreos-fix-selinux-labels.service runs before zincati.service
# let's wait until that service is finished before proceeding (and potentially
# timing out below as a result of not waiting here). Note that if we are
# running on an older release that doesn't have coreos-fix-selinux-labels.service
# this is essentially a no-op.
systemd-run --wait --property=After=coreos-fix-selinux-labels.service \
    echo "Waited for coreos-fix-selinux-labels.service to finish"

# If we have made it all the way to the last release then
# we have one more test. We'll now rebase to the target
# version, which should be in the compose OSTree repo.
if vereq $version $last_release; then
    # Since we'll be manually running `rpm-ostree` let's stop zincati
    systemctl stop zincati

   # XXX: Since we can't rely on `ostree-image-signed` until the
   #      streams have switched over to it we have to comment out the
   #      true part of this if statement for now.
   #
   #inspect=$(skopeo inspect --retry-times=3 -n docker://quay.io/fedora/fedora-coreos:${target_stream})
   #registry_version=$(jq -r '.Labels."org.opencontainers.image.version"' <<< "${inspect}")
   #if [ "${registry_version}" == "${target_version}" ]; then
   #    # If the container is already pushed to the registry we'll use the registry
   #    if [ "${stream}" == "${target_stream}" ]; then
   #        # If we aren't switching steams we can just upgrade
   #        rpm-ostree upgrade
   #    else
   #        # else we need to rebase
   #        rpm-ostree rebase "ostree-image-signed:docker://quay.io/fedora/fedora-coreos:{target_stream}"
   #    fi
   #else
        # Since in the next steps we are making multiple copies of the update on the
        # system (i.e. update.ociarchive and copying into OSTree storage) let's free
        # up some space by dropping the rollback deployment.
        rpm-ostree cleanup --rollback
        # Pull the ociarchive from the builds dir here because the
        # containers aren't pushed to quay yet. This can happen in the
        # case where the release job isn't autotriggered (i.e. prod builds)
        # or if somehow the release job failed.
        curl -L -o /srv/update.ociarchive \
            "https://builds.coreos.fedoraproject.org/prod/streams/${target_stream}/builds/${target_version}/${arch}/fedora-coreos-${target_version}-ostree.${arch}.ociarchive"
        rpm-ostree rebase "ostree-unverified-image:oci-archive:/srv/update.ociarchive"
        rm /srv/update.ociarchive
   #fi
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

# OK update has been initiated. Let's fork off a process that will wait until
# the deployment is written before signaling the impending reboot. Waiting
# before signaling reboot will mean we get less timeouts in the code that
# waits for the reboot to happen.
#
# The strategy of using systemd-run for this was lifted from
# https://github.com/coreos/coreos-assembler/commit/242a88eae7e167efa9e04dcef9b751c6df137333
#
# On <35 SELinux won't allow a path unit to monitor /ostree/deploy, so disable
verlt $version '35.00000000.0.0' && setenforce 0
systemd-run -u refchanged                      \
    --path-property=PathChanged=/ostree/deploy \
    bash /tmp/autopkgtest-reboot-prepare $version

# While we wait, loop to show status of zincati and rpm-ostreed
while true; do
    sleep 30
    # Ignore error here. Older systemd (~F32) errors here if one of
    # the services isn't active.
    systemctl status rpm-ostreed zincati --lines=0 || true
done
