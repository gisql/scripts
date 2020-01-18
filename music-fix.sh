#!/usr/bin/env bash

export BASE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
. "$BASE/common.sh"

require id3v2 jq mp3info metaflac

function copy_album() {
    local src=${1?Source directory of album}
    local dst_root=${2?Root of the destination hierarchy}

    local artist=$(jq -r '.artists[0].name' < "$src/master-info.json" | sed 's/\//-/g')
    local year=$(jq -r '.year' < "$src/master-info.json")
    local album=$(jq -r '.title' < "$src/master-info.json" | sed 's/\//-/g')

    local dst="$dst_root/$artist/[$year] $album"
    if [[ ! -d "$dst" ]]; then
        mkdir -p "$dst"
        cp -l "$src"/*.mp3 "$src"/*.flac "$src"/master*.json "$src"/master-info.txt "$dst" 2> /dev/null
    fi
    echo "$dst"
}

function find_track() {
    local dir=$(normalise_dir "${1?Directory with tracks}")
    local n=$(printf "%02d" "${2?Track number}")

    if [[ $(find "$dir" -maxdepth 1 \( -iname "*$n*.mp3" -o -iname "*$n*.flac" \) -type f | wc -l) -eq 1 ]]; then
        find "$dir" -maxdepth 1 \( -iname "*$n*.mp3" -o -iname "*$n*.flac" \) -type f
    elif [[ $(find "$dir" -maxdepth 1 \( -iname "$n*.mp3" -o -iname "$n*.flac" \) -type f | wc -l) -eq 1 ]]; then
        find "$dir" -maxdepth 1 \( -iname "$n*.mp3" -o -iname "$n*.flac" \) -type f
    else
        n=$(expr "$n" + 0)
        debug "Looking for track $n in $dir by tag"
        rv=$(music_files "$dir" | while read -r i; do
            local ext="$(echo "${i##*.}" | tr '[:upper:]' '[:lower:]')"

            if [[ $ext == "flac" ]]; then
                debug "track in $(basename "$i"): $(metaflac --show-tag=TRACKNUMBER "$i")"
                ftr=$(expr 0 + "$(metaflac --show-tag=TRACKNUMBER "$i" | sed -e 's/.*=//' -e 's/\/.*//g' 2> /dev/null)")
            else
                ftr=$(mp3info -p '%n' "$i" 2> /dev/null)
            fi

            if [ "$ftr" == "$n" ]; then
                echo "$i"
            fi
        done)
        if [[ -f $rv ]]; then
            debug "Found $rv"
            echo "$rv"
        else
            warn "Couldn't find track number $n in directory $dir"
        fi
    fi
}

function tag_file() {
    local dst=${1?Destination file}
    local artist=${2?Track Artist}
    local title=${3?Track title}
    local album_year=${4?Album year}
    local album=${5?Album title}
    local track=${6?Track number}

    [[ -f $dst ]] || return

    debug "Tagging $out"

    local ext="$(echo "${dst##*.}" | tr '[:upper:]' '[:lower:]')"

    if [[ $ext == "flac" ]]; then
        metaflac --remove-all-tags --set-tag=ARTIST="$artist" --set-tag=TITLE="$title" --set-tag=DATE="$album_year" \
            --set-tag=ALBUM="$album" --set-tag=TRACKNUMBER="$track" "$dst"
    else
        id3v2 -a "$artist" -A "$album" -t "$title" -y "$album_year" -T "$track" "$dst"
    fi
}

function process_album() {
    local src=${1?Source directory of album}
    local dst_root=${2?Root of the destination hierarchy}
    local dst=$(copy_album "$src" "$dst_root")

    [[ -d $dst ]] || return

    local artist=$(jq -r '.artists[0].name' < "$src/master-info.json" | sed 's/\//-/g')
    local year=$(jq -r '.year' < "$src/master-info.json" | sed 's/\//-/g')
    local album=$(jq -r '.title' < "$src/master-info.json" | sed 's/\//-/g')
    local track_count=$(jq -r '.tracklist | map(select(.type_ == "track")) | length' < "$dst/master-info.json")
    local cover_url=$(jq .results < "$dst/masters.json" | jq 'sort_by(-.community.have)' | jq -r .[].cover_image | head -1)
    if [[ -f "$dst/cover.jpg" ]]; then
        debug "Cover art already downloaed"
    else
        curl -s "$cover_url" > "$dst/cover.jpg"
        sleep 3
    fi

    local tracks=$(mktemp)
    jq -r '.tracklist | map(select(.type_ == "track"))' < "$dst/master-info.json" > "$tracks"
    for n in $(seq "$track_count"); do
        local i=$(("$n" - 1))
        local in=$(find_track "$dst" "$n")
        local ext="$(echo "${in##*.}" | tr '[:upper:]' '[:lower:]')"

        [[ -f $in ]] || continue
        local track_artist=$(jq -r ".[$i].artists[0].name" < "$tracks")
        [[ -z $track_artist || $track_artist == "null" ]] && track_artist="$artist"
        local title=$(jq -r ".[$i].title" < "$tracks")
        local out=$(printf "%02d - %s.%s" "$n" "$title" "$ext" | sed 's/\//-/g')
        [[ -f "$dst/$out" ]] || mv "$in" "$dst/$out"
        tag_file "$dst/$out" "$track_artist" "$title" "$year" "$album" "$n"
        true
    done
    rm -f "$tracks"
}

SRC_ROOT=${1?Root directory containing music to be sorted}
DST_ROOT=${2-/media/michcio/green/music-sorted}

[[ -d "$SRC_ROOT" ]] || die "Directory $SRC_ROOT doesn't exist"

mkdir -p "$DST_ROOT"
#rm -rf "${DST_ROOT:?}"/*
find "$SRC_ROOT" -name 'master-info.txt' | while read -r i; do
    grep -qF "WRONG COUNT" "$i" && continue
    debug "Processing $i"
    process_album "$(dirname "$i")" "$DST_ROOT"
done
