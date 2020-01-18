#!/usr/bin/env bash

export BASE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
. "$BASE/common.sh"

ALBUM_DIR="$(normalise_dir "${1?Album Dir}")"
EXT="${2?File extension}"

n=1
find "$ALBUM_DIR" -name "*.$EXT" | sort | while read -r i; do
    mv "$i" "$ALBUM_DIR/$(printf %02d "$n").$EXT"
    ((n++))
done
