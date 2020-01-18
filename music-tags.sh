#!/usr/bin/env bash

#set -e

export BASE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
. "$BASE/common.sh"

require DISCOGS_TOKEN id3v2 jq mp3info metaflac

function mp3_1_tag() {
    local tag=${1?logical tag}
    local file=${2?file to extract tag from}

    case $tag in
    ARTIST)
        mp3info -p "%a\n" "$file" 2> /dev/null
        ;;
    ALBUM)
        mp3info -p "%l\n" "$file" 2> /dev/null
        ;;
    YEAR)
        mp3info -p "%y\n" "$file" 2> /dev/null
        ;;
    esac
}

function mp3_2_tag() {
    local tag=${1?logical tag}
    local file=${2?file to extract tag from}

    case $tag in
    ARTIST)
        id3v2 -l "$file" 2> /dev/null | grep "^TPE1" | sed 's/.*: //' 2> /dev/null
        ;;
    ALBUM)
        id3v2 -l "$file" 2> /dev/null | grep "^TALB" | sed 's/.*: //' 2> /dev/null
        ;;
    YEAR)
        id3v2 -l "$file" 2> /dev/null | grep "^TYER" | sed 's/.*: //' 2> /dev/null
        ;;
    esac
}

function mp3_tag() {
    local tag=${1?logical tag}
    local file=${2?file to extract tag from}

    local rv=$(mp3_2_tag "$tag" "$file")
    [[ -z $rv ]] && rv=$(mp3_1_tag "$tag" "$file")
    echo "$rv"
}

function flac_tag() {
    local tag=${1?logical tag}
    local file=${2?file to extract tag from}

    case $tag in
    ARTIST)
        metaflac --show-tag=ARTIST "$file" | sed 's/.*=//' 2> /dev/null
        ;;
    ALBUM)
        metaflac --show-tag=ALBUM "$file" | sed 's/.*=//' 2> /dev/null
        ;;
    YEAR)
        metaflac --show-tag=DATE "$file" | sed 's/.*=//' 2> /dev/null
        ;;
    esac
}

function file_tag() {
    local tag=${1?logical tag}
    local file=${2?file to extract tag from}
    local ext="${file##*.}"
    case $ext in
    mp3)
        mp3_tag "$tag" "$file"
        ;;
    flac)
        flac_tag "$tag" "$file"
        ;;
    esac
}

function music_files() {
    local dir=${1?input directory}

    find "$(normalise_dir "$dir")" -maxdepth 1 \( -iname "*.mp3" -o -iname "*.flac" \) -type f
}

function music_dirs() {
    local dir=${1?input directory}
    find "$(normalise_dir "$dir")" \( -iname "*.mp3" -o -iname "*.flac" \) -type f -exec dirname '{}' \; | sort -u
}

function most_common_tag() {
    local dir=${1?input directory}
    local tag=${2?logical tag}
    music_files "$dir" | while read -r i; do
        file_tag "$tag" "$i"
    done |
        grep -v "^ *$" | tr '[:upper:]' '[:lower:]' |
        sort | uniq -c | sort -rn | head -1 |
        awk '{first = $1; $1 = ""; print $0; }' | sed -e 's/^ *//' # -e 's/ *$//g'
}

function cuetag_dir() {
    local album_dir=${1?Album Dir}
    pushd "$album_dir" > /dev/null || true
    find "$album_dir" -maxdepth 1 -name "*.cue" -type f | wc -l | grep -q '^1$' || return
    find "$album_dir" -maxdepth 1 -name "*.flac" -type f | wc -l | grep -q '^1$' || return
    cue=$(find "$album_dir" -maxdepth 1 -name "*.cue" -type f)
    cuetag "$cue" "$(find "$album_dir" -maxdepth 1 -name "*.flac" -type f)"
    popd > /dev/null || true
}

function discogs() {
    local out=$(mktemp)
    curl -s -X GET -G -H "Authorization: Discogs token=$DISCOGS_TOKEN" "https://api.discogs.com/database/search" "$@" > "$out"
    local delay=1
    while grep -Fq 'You are making requests too' "$out"; do
        sleep "$delay"
        curl -s -X GET -G -H "Authorization: Discogs token=$DISCOGS_TOKEN" "https://api.discogs.com/database/search" "$@" > "$out"
        delay=$(expr "$delay" + "$delay")
    done
    cat "$out"
    rm -f "$out"
}

function process_album() {
    local album_dir=${1?Album Dir}
    [[ -d ${album_dir} ]] || die "$album_dir doesn't exist"
    album_dir=$(normalise_dir "$album_dir")
    cuetag_dir "$album_dir"

    local year=$(most_common_tag "$album_dir" YEAR)
    local artist=$(most_common_tag "$album_dir" ARTIST)
    local album=$(most_common_tag "$album_dir" ALBUM)

    if [[ -f "$album_dir/masters.json" && -f "$album_dir/master-info.json" ]]; then
        debug "Master information already exists.  Skipping query for $album_dir"
    elif [[ -z $year && -z $artist && -z $album ]]; then
        warn "Directory $album_dir doesn't contain any files with tags"
        return
    else
        discogs -d "release_title=$album" -d "year=$year" -d "artist=$artist" -d "type=master" -d "per_page=100" |
            jq . > "$album_dir/masters.json"
        sleep 1 ## we are throttled at 60 requests a minute

        if [[ $(jq -r .pagination.items < "$album_dir/masters.json") -eq 0 ]]; then
            album=$(sed -e 's/ *[\[(].*[])]//g' -e 's/cd[0-9]//gi' <<< "$album")

            discogs -d "release_title=$album" -d "year=$year" -d "artist=$artist" -d "type=master" -d "per_page=100" |
                jq . > "$album_dir/masters.json"
            sleep 1 ## we are throttled at 60 requests a minute
        fi
        if [[ $(jq -r .pagination.items < "$album_dir/masters.json") -eq 0 ]]; then
            discogs -d "release_title=$album" -d "year=$year" -d "artist=$artist" -d "per_page=100" |
                jq . > "$album_dir/masters.json"
            sleep 1 ## we are throttled at 60 requests a minute
        fi
        if [[ $(jq -r .pagination.items < "$album_dir/masters.json") -eq 0 ]]; then
            discogs -d "release_title=$album" -d "artist=$artist" -d "per_page=100" |
                jq . > "$album_dir/masters.json"
            sleep 1 ## we are throttled at 60 requests a minute
        fi
        most_owned=$(jq .results < "$album_dir/masters.json" | jq 'sort_by(-.community.have)' | jq -r .[].resource_url | head -1)

        sleep 1
        curl -s "$most_owned" | jq . > "$album_dir/master-info.json"
        sleep 3 ## we are throttled at 25 requests a minute
    fi

    local track_count=$(jq -r '.tracklist | map(select(.type_ == "track")) | length' < "$album_dir/master-info.json")
    local file_count=$(music_files "$album_dir" | wc -l)
    cat << EOF > "$album_dir/master-info.txt"
Information generated on $(date) for directory: $album_dir
Query executed: release_title="$album"     year="$year"     artist="$artist"

Track count    $track_count
File count     $file_count $(if [[ $track_count -ne $file_count ]]; then echo "WRONG COUNT"; else echo "OK"; fi)
Album Title    $(jq -r '.title' < "$album_dir/master-info.json")
Main Artist    $(jq -r '.artists[0].name' < "$album_dir/master-info.json")

$(jq -r '.tracklist | map(select(.type_ == "track")) | .[] | "Track #\(.position)\t\(.title)"' < "$album_dir/master-info.json")
EOF
}

if [[ $1 == "force" ]]; then
    FORCE=true
    shift
else
    FORCE=flase
fi

MUSIC_ROOT=${1?Root directory containing music}

if [[ $FORCE == true ]]; then
    warn "All previously download info files are going to be removed from $MUSIC_ROOT"
    find "$MUSIC_ROOT" \( -name "master-info.txt" -o -name "*.json" \) -type f -exec rm '{}' \;
fi

music_dirs "$MUSIC_ROOT" | while read -r i; do
    debug "Processing directory: $i"
    process_album "$i"
done
