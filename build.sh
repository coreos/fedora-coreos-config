#!/bin/sh

image="docker.io/antora/antora"
cmd="--html-url-extension-style=indexify site.yml"

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

    if [ -f /usr/bin/podman ]; then
        echo ""
        echo "This build script is using Podman to run the build in an isolated environment."
        echo ""
	podman run --rm -it -v $(pwd):/antora:z $image $cmd

    elif [ -f /usr/bin/docker ]; then
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
