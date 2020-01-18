#!/usr/bin/env bash

export BASE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
. "$BASE/common.sh"

require id3v2 jq mp3info metaflac

function force_info() {
    local album_dir="$(normalise_dir "${1?Album Dir}")"
    local db_id=${2?Db Id}
    [[ -d ${album_dir} ]] || die "$album_dir doesn't exist"

    curl -q "https://api.discogs.com/$db_id" > "$album_dir/master-info.json"
    sleep 3

    local track_count=$(jq -r '.tracklist | map(select(.type_ == "track")) | length' < "$album_dir/master-info.json")
    local file_count=$(music_files "$album_dir" | wc -l)
    cat << EOF > "$album_dir/master-info.txt"
Information generated on $(date) for directory: $album_dir
Forced from id: $db_id

Track count    $track_count
File count     $file_count $(if [[ $track_count -ne $file_count ]]; then echo "WRONG COUNT"; else echo "OK"; fi)
Album Title    $(jq -r '.title' < "$album_dir/master-info.json")
Main Artist    $(jq -r '.artists[0].name' < "$album_dir/master-info.json")

$(jq -r '.tracklist | map(select(.type_ == "track")) | .[] | "Track #\(.position)\t\(.title)"' < "$album_dir/master-info.json")
EOF
}

ALBUM_DIR=${1?Album directory}
DST_ROOT=${2?Root desination directory}
DB_ID=${3?Discogs DB id in for releases|masters/number}

[[ -d "$ALBUM_DIR" ]] || die "Directory $ALBUM_DIR doesn't exist"

tmp=$(mktemp -p "$ALBUM_DIR" -d)

n=1
music_files "$ALBUM_DIR" | sort | while read -r i; do
    ext="${i##*.}"
    cp -l "$i" "$tmp/$(printf %02d "$n").$ext"
    ((n++))
done

force_info "$tmp" "$DB_ID"
[ -f "$ALBUM_DIR/masters.json" ] && cp "$ALBUM_DIR/masters.json" "$tmp"

"$BASE"/music-fix.sh "$tmp" "$DST_ROOT"

rm -rf "$tmp"
