#!/bin/bash

#This is a common library created for the ok & fatal function 
#and symlinks added to the data/ in each directory

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}
