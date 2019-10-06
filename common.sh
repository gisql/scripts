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

function require() {
    local BASE=$(cd "$(dirname "$0")" && pwd)
    # shellcheck disable=SC1090
    [[ -x "$BASE/secrets" ]] && . "$BASE/secrets"
    for i in "$@"; do
        if [[ $i =~ ^[A-Z_][A-Z_0-9]*$ ]]; then
            [[ -z ${!i} ]] && die "Variable '$i' has to be defined or included in an executable $BASE/secrets script"
        else
            hash "$i" 2> /dev/null || die "Command '$i' has to be PATH"
        fi
    done
}

function debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "$*"
    fi
}

function info() {
    echo "$*"
}

function warn() {
    echo "WARNING $*"
}

export -f die
export -f normalise_dir
export -f require
export -f debug
