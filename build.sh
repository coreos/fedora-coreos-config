#!/bin/sh

image="docker.io/antora/antora"
cmd="--html-url-extension-style=indexify site.yml"

if uname | grep -iwq darwin; then
    # Running on macOS.
    # Let's assume that the user has the Docker CE installed
    # which doesn't require a root password.
    echo ""
    echo "This build script is using Docker container runtime to run the build in an isolated environment."
    echo ""
    docker run --rm -it -v "$(pwd):/antora" "${image}" ${cmd}

elif uname | grep -iq linux; then
    # Running on Linux.
    # there isn't an antora/aarch64 container, antora can be installed locally
    # Check whether podman is available, else faill back to docker
    # which requires root.

    if [ -f /usr/local/bin/antora ]; then
        /usr/local/bin/antora "${cmd}"
    elif uname -m | grep -iwq aarch64; then
        echo "no antora/aarch64 container try just \`npm install -g @antora/cli @antora/site-generator-default\`"
    elif [ -f /usr/bin/podman ]; then
        echo ""
        echo "This build script is using Podman to run the build in an isolated environment."
        echo ""
        podman run --rm -it -v "$(pwd):/antora:z" "${image}" ${cmd}

    elif [ -f /usr/bin/docker ]; then
        echo ""
        echo "This build script is using Docker to run the build in an isolated environment."
        echo ""

        if groups | grep -wq "docker"; then
            docker run --rm -it -v "$(pwd):/antora:z" "${image}" ${cmd}
        else
            echo "You might be asked for your password."
            echo "You can avoid this by adding your user to the 'docker' group,"
            echo "but be aware of the security implications."
            echo "See https://docs.docker.com/install/linux/linux-postinstall/"
            echo ""
            sudo docker run --rm -it -v "$(pwd):/antora:z" "${image}" ${cmd}
        fi
    else
        echo ""
        echo "Error: Container runtime haven't been found on your system. Fix it by:"
        echo "$ sudo dnf install podman"
        exit 1
    fi
fi
