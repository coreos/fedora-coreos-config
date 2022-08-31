#!/bin/bash
# script to watch source directory for changes, and re-run build and preview
#
# License: MIT
# https://fedoraproject.org/wiki/Licensing:MIT#Another_Minimal_variant_(found_in_libatomic_ops)
#
# Copyright (c) Fedora community contributors.
#
# THIS MATERIAL IS PROVIDED AS IS, WITH ABSOLUTELY NO WARRANTY EXPRESSED OR
# IMPLIED. ANY USE IS AT YOUR OWN RISK.
#
# Permission is hereby granted to use or copy this program for any purpose,
# provided the above notices are retained on all copies.  Permission to modify
# the code and to distribute modified code is granted, provided the above
# notices are retained, and a notice that the code was modified is included
# with the above copyright notice.


script_name="docsbuilder.sh"
script_source="https://gitlab.com/fedora/docs/templates/fedora-docs-template/-/raw/main/${script_name}"
version="1.2.0"
image="docker.io/antora/antora"
cmd="--html-url-extension-style=indexify site.yml"
srcdir="modules"
buildir="public"
previewpidfile="preview.pid"

# 4913: for vim users, vim creates a temporary file to test it can write to
# directory
# https://groups.google.com/g/vim_dev/c/sppdpElxY44
# .git: so we don't get rebuilds each time git metadata changes
inotifyignore="\.git.*|4913"

watch_and_build () {
    if ! command -v inotifywait > /dev/null
    then
        echo "inotifywait command could not be found. Please install inotify-tools."
        echo "On Fedora, run: sudo dnf install inotify-tools"
        stop_preview_and_exit
    else
        # check for git
        # required to get ignorelist
        if ! command -v git > /dev/null
        then
            echo "git command could not be found. Please install git."
            echo "On Fedora, run: sudo dnf install git-core"
            stop_preview_and_exit
        else
            # Get files not being tracked, we don't watch for changes in these.
            # Could hard code, but people use different editors that may create
            # temporary files that are updated regularly and so on, so better
            # to get the list from git. It'll also look at global gitingore
            # settings and so on.
            inotifyignore="$(git status -s --ignored | grep '^!!' | sed -e 's/^!! //' | tr '\n' '|')${inotifyignore}"
        fi

        while true
        do
            echo "Watching current directory (excluding: ${inotifyignore}) for changes and re-building as required. Use Ctrl C to stop."
            inotifywait -q --exclude "($inotifyignore)" -e modify,create,delete,move -r . && echo "Change detected, rebuilding.." && build
        done
    fi
}

build () {
    if [ "$(uname)" == "Darwin" ]; then
        # Running on macOS.
        # Let's assume that the user has the Docker CE installed
        # which doesn't require a root password.
        echo ""
        echo "This build script is using Docker container runtime to run the build in an isolated environment."
        echo ""
        docker run --rm -it -v $(pwd):/antora $image $cmd

    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        # Running on Linux.
        # Check whether podman is available, else faill back to docker
        # which requires root.

        if [ -n "$(command -v podman)" ]; then
            echo ""
            echo "This build script is using Podman to run the build in an isolated environment."
            echo ""
            podman run --rm -it -v $(pwd):/antora:z $image $cmd --stacktrace

        elif [ -n "$(command -v docker)" ]; then
            echo ""
            echo "This build script is using Docker to run the build in an isolated environment."
            echo ""

            if groups | grep -wq "docker"; then
                docker run --rm -it -v $(pwd):/antora:z $image $cmd
            else
                    echo ""
                    echo "This build script is using $runtime to run the build in an isolated environment. You might be asked for your password."
                    echo "You can avoid this by adding your user to the 'docker' group, but be aware of the security implications. See https://docs.docker.com/install/linux/linux-postinstall/."
                    echo ""
                    sudo docker run --rm -it -v $(pwd):/antora:z $image $cmd
            fi

        else
            echo ""
        echo "Error: Container runtime haven't been found on your system. Fix it by:"
        echo "$ sudo dnf install podman"
        exit 1
        fi
    fi
}

start_preview () {

    # clean up a preview that may be running
    stop_preview

    # always run an initial build so preview shows latest version
    build

    if [ "$(uname)" == "Darwin" ]; then
        # Running on macOS.
        # Let's assume that the user has the Docker CE installed
        # which doesn't require a root password.
        echo "The preview will be available at http://localhost:8080/"
        docker run --rm -v $(pwd):/antora:ro -v $(pwd)/nginx.conf:/etc/nginx/conf.d/default.conf:ro -p 8080:80 nginx

    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        # Running on Linux.
        # Fedora Workstation has python3 installed as a default, so using that
        echo ""
        echo "The preview is available at http://localhost:8080"
        echo ""
        pushd "${buildir}"  > /dev/null 2>&1
            python3 -m http.server 8080 &
            echo "$!" > ../"${previewpidfile}"
        popd > /dev/null 2>&1
    fi
}

stop_preview () {
    if [ -e "${previewpidfile}" ]
    then
        PID=$(cat "${previewpidfile}")
        kill $PID
        echo "Stopping preview server (running with PID ${PID}).."
        rm -f "${previewpidfile}"
    else
        echo "No running preview server found to stop: no ${previewpidfile} file found."
    fi
}

stop_preview_and_exit ()
{
    # stop and also exit the script

    # if stop_preview is trapped, then SIGINT doesn't stop the build loop. So
    # we need to make sure we also exit the script.

    # stop_preview is called before other functions, so we cannot add exit to
    # it.
    stop_preview
    exit 0
}


# https://apple.stackexchange.com/questions/83939/compare-multi-digit-version-numbers-in-bash/123408#123408
version () { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4);  }';  }


check_update () {
    if ! command -v curl > /dev/null
    then
        echo "curl command could not be found. Please install curl."
        echo "On Fedora, run: sudo dnf install curl"
        exit 0
    fi
    script_version="$(grep "^version=" ${script_name} | cut -d '=' -f2 | tr --delete '"')"
    tempdir="$(mktemp -d)"
    echo "$tempdir"
    pushd "$tempdir" > /dev/null 2>&1
        curl "$script_source" --silent --output "${script_name}"
        upstream_version="$(grep "^version=" ${script_name} | cut -d '=' -f2 | tr --delete '"')"
        echo "${upstream_version}"
        if [ $(version $upstream_version) -gt $(version $script_version)  ]; then
            echo "Update available"
            echo "Script version $upstream_version is available at $script_source"
            echo "This version is $script_version."
            echo "Please use the '-U' option to update."
            echo
        fi
    popd > /dev/null 2&>1
}

install_update () {
    if ! command -v curl > /dev/null
    then
        echo "curl command could not be found. Please install curl."
        echo "On Fedora, run: sudo dnf install curl"
        exit 0
    fi
    curl "$script_source" --silent --output "${script_name}.new"
    mv "${script_name}.new" "${script_name}"
    chmod +x "${script_name}"
}

usage() {
    echo "$0: Build and preview Fedora antora based documentation"
    echo
    echo "Usage: $0 [-awbpkh]"
    echo
    echo "-a: start preview, start watcher and rebuilder"
    echo "-w: start watcher and rebuilder"
    echo "-b: rebuild"
    echo "-p: start_preview"
    echo "-k: stop_preview"
    echo "-h: print this usage text and exit"
    echo "-u: check builder script update"
    echo "-U: install builder script from upstream"
    echo
    echo "Maintained by the Fedora documentation team."
    echo "Please contact on our channels: https://docs.fedoraproject.org/en-US/fedora-docs/#find-docs"
}

# check if the script is being run in a Fedora docs repository
if [ ! -e "site.yml" ]
then
    echo "site.yml not be found."
    echo "This does not appear to be a Fedora Antora based documentation repository."
    echo "Exiting."
    echo
    usage
    exit 1
fi


if [ $# -lt 1 ]
then
    echo "No options provided, running preview with watch and build."
    echo "Run script with '-h' to see all available options."
    echo
    echo
    trap stop_preview_and_exit INT
    start_preview
    watch_and_build
    stop_preview
fi

# parse options
while getopts "awbpkhuU" OPTION
do
    case $OPTION in
        a)
            # handle sig INT to stop the preview
            trap stop_preview_and_exit INT
            start_preview
            watch_and_build
            stop_preview
            exit 0
            ;;
        w)
            watch_and_build
            exit 0
            ;;
        b)
            build
            exit 0
            ;;
        p)
            start_preview
            echo "Please run ./${script_name} -k to stop the preview server"
            exit 0
            ;;
        k)
            stop_preview
            exit 0
            ;;
        h)
            usage
            exit 0
            ;;
        u)
            check_update
            exit 0
            ;;
        U)
            install_update
            exit 0
            ;;
        ?)
            usage
            exit 1
            ;;
    esac
done
