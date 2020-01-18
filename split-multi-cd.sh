#!/usr/bin/env bash

export BASE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
. "$BASE/common.sh"

require shnsplit cuetag

function count_ext_in_dir() {
    local dir=$(normalise_dir "${1?Directory to count}")
    local ext=${2?Extension}
    find "$dir" -maxdepth 1 -name "*.$ext" -type f | wc -l
}

work="$(normalise_dir "${1?Directory To Split}")"
shift

if [[ $# -eq 0 ]]; then
    arr=()
    [[ $(count_ext_in_dir "$work" "cue") -eq $(count_ext_in_dir "$work" "flac") ]] || die "Provide pairs of flacs cues to work"
    while read -r cue; do
        flac="$(dirname "$cue")/$(basename "$cue" .cue).flac"
        [[ -f "$flac" ]] || die "Flac $flac for cue $cue doesn't exist, please invoke script with explicit pairs"
        arr+=("$cue" "$flac")
    done < <(find "$work" -maxdepth 1 -name "*.cue" -type f | sort)

    "$BASE"/split-multi-cd.sh "$work" "${arr[@]}"
else
    [[ $(expr $# % 2) -eq 0 ]] || die "Provide cue and flac in pairs"

    n=1
    out=$(mktemp -p "$work" -d)
    pushd "$out" > /dev/null || die "Coudln't change directory to $out"
    while [[ $# -gt 0 ]]; do
        cue="$1"
        shift
        flac="$1"
        shift

        [[ -f "$cue" ]] || die "Cue file $cue doesn't exist"
        [[ -f "$flac" ]] || die "Flac file $flac doesn't exist"
        shnsplit -f "$cue" -t "$n.%n-%t" -o flac "$flac"
        cuetag "$cue" $n.*.flac
        ((n++))
        rm -f "$flac"
    done
    popd > /dev/null || die "Coudn't come back"

    out=$(echo "$work"/tmp.*)
    n=1
    while read -r f; do
        mv "$f" "$work/$(printf %02d "$n").flac"
        ((n++))
    done < <(find "$out" -maxdepth 1 -name "*.flac" -type f | sort)
    rm -rf "$out"

    rm -f "$work"/*.json
    rm -f "$work"/master-info.txt

    "$BASE"/music-tags.sh "$work"
fi
