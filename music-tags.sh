#!/usr/bin/env bash

set -e

export BASE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
. "$BASE/common.sh"
die "$BASE"
hash id3v2
