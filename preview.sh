#!/bin/sh

if [ "$(uname)" == "Darwin" ]; then
    # Running on macOS.
    # Let's assume that the user has the Docker CE installed
    # which doesn't require a root password.
    echo "The preview will be available at http://localhost:8080/"
    docker run --rm -v $(pwd)/public:/usr/share/nginx/html:ro -p 8080:80 nginx

elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # Running on Linux.
    # Let's assume that it's running the Docker deamon
    # which requires root.
    echo ""
    echo "This build script is using Docker to run the build in an isolated environment. You might be asked for a root password in order to start it."
    echo "The preview will be available at http://localhost:8080/"
    sudo docker run --rm -v $(pwd)/public:/usr/share/nginx/html:ro -p 8080:80 nginx
fi
