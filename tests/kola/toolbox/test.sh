#!/bin/bash
## kola:
##   tags: "platform-independent needs-internet"
##   # Toolbox container is currently available only for x86_64 and aarch64 in Fedora
##   architectures: x86_64 aarch64
##   description: Make sure that basic toolbox functionality works (creating,
##     running commands, and removing).
##   creationDate: 2026-05-05
# IMPORTANT: Commands are run indirectly via `run_as_core_user` to re-create the
# user environment needed for unprivileged podman functionality.

set -xeuo pipefail

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

# Functions for testing basic functionality - overridden depending on toolbox being used
toolbox_create() {
    run_as_core_user /bin/toolbox create --assumeyes
}

toolbox_run_basic() {
    run_as_core_user /bin/toolbox run touch ok_toolbox
}

toolbox_list() {
    run_as_core_user /bin/toolbox list --containers
}

toolbox_count() {
    toolbox_list | grep --count -E "(fedora|rhel)-toolbox-" || true
}

toolbox_rm() {
    toolbox="$(toolbox_list | awk '/(fedora|rhel)-toolbox-/ {print $2}')"
    run_as_core_user /bin/toolbox rm -f "${toolbox}"
}

# Older variants (e.g. RHEL-9.8) use https://github.com/coreos/toolbox
# NOTE: script uses privileged podman
if file /bin/toolbox | grep -q "shell script"; then
    echo "Using toolbox script <https://github.com/coreos/toolbox>"

    # Create configuration for coreos/toolbox
    rhel_major_version=$(get_rhel_maj_ver)
    cat << EOF > /var/home/core/.toolboxrc
REGISTRY=registry.access.redhat.com
IMAGE=ubi${rhel_major_version}/toolbox:latest
TOOLBOX_NAME=rhel-toolbox-latest
AUTHFILE=/var/home/core/config.json
EOF
    # Toolbox fails if the AUTHFILE does not exist, but we don't actually need credentials
    echo '{}' > /var/home/core/config.json

    toolbox_create() {
        # Container created on first run of any command
        run_as_core_user /bin/toolbox true
    }

    toolbox_run_basic() {
        run_as_core_user /bin/toolbox touch /host/home/core/ok_toolbox
    }

    toolbox_list() {
        /bin/podman ps -a
    }

    toolbox_rm() {
        toolbox="$(toolbox_list | awk '/(fedora|rhel)-toolbox-/ {print $1}')"
        /bin/podman rm -f "${toolbox}"
    }
elif is_rhcos; then
    # When using an image that's not yet released (e.g.
    # 10.2 as of writing this) the image won't exist in the
    # registry. Let's just use the `:latest` tag so we don't
    # hit that problem.
    rhel_major_version=$(get_rhel_maj_ver)
    cat << EOF > /etc/containers/toolbox.conf
[general]
image = "registry.access.redhat.com/ubi${rhel_major_version}/toolbox:latest"
EOF
fi

# Try five times to create the toolbox to avoid container registry infra flakes
for i in {1..5}; do
    toolbox_create || true
    if [[ $(toolbox_count) -eq 1 ]]; then
        break
    fi

    if [[ $i -eq 5 ]]; then
        fatal "Could not create toolbox after 5 attempts"
    fi

    echo "Could not create toolbox on try: $i"
    sleep 10
done
ok toolbox create

toolbox_run_basic
if [[ ! -f '/home/core/ok_toolbox' ]]; then
    fatal "Could not run a simple command inside a toolbox"
fi
ok toolbox run

toolbox_rm
if [[ $(toolbox_count) -ne 0 ]]; then
    fatal "Could not remove the toolbox container"
fi
ok toolbox rm
