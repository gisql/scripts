#!/bin/bash

usage="USAGE: $0 <book title> <writer> <reader> <year> [<series title>]"
title=${1?${usage}}
artist=${2?${usage}}
reader=${3?${usage}}
year=${4?${usage}}
series=${5-$title}

N=$(find -name '*.mp3' | head -1 | sed 's/.*_\([0-9]*\)\.mp3$/\1/g')
mid=$(find -name '*.mp3' | head -1 | sed 's/[^0-9]*[0-9]*_\(.*\)_[0-9]*\.mp3$/\1/g')
len=$(echo -ne $N | wc -c)
for n in `seq -f "%0${len}g" $N`; do
	name="${n}_${mid}_${N}.mp3"
	id3v2 -D $name
	id3v2 -t "$title $n/$N" -T $n -a "$artist" -A "$series" -c "Read by $reader" -g 101 -y "$year" $name
done
ls -1 | grep mp3 | sort -n > "${mid}.m3u"
rm -f doit
