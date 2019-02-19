#!/bin/sh

if [ "$(uname)" == "Darwin" ]; then
    # Running on macOS.
    # Let's assume that the user has the Docker CE installed
    # which doesn't require a root password.
    docker run --rm -it -v $(pwd):/antora antora/antora --html-url-extension-style=indexify site.yml

elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # Running on Linux.
    # Let's assume that it's running the Docker deamon
    # which requires root.
    echo ""
    echo "This build script is using Docker to run the build in an isolated environment. You might be asked for a root password in order to start it."
sudo docker run --rm -it -v $(pwd):/antora:z antora/antora --html-url-extension-style=indexify site.yml
fi
