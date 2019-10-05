#!/usr/bin/env bash

function die() {
    echo "$*" 1>&2
    exit 1
}

function normalise_dir() {
    pushd "$1" > /dev/null || exit 1
    local rv=$(pwd)
    popd > /dev/null || exit 1
    echo "$rv"
}

export -f die
export -f normalise_dir
