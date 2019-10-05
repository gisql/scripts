#!/bin/bash

dir=${1?directory name, pls}

N=$(find $dir -type f -iname '*.mp3' | wc -l)
len=$(echo -ne $N | wc -c)

mid=$(basename $dir | sed 's/^[0-9]*_//g')

n=1
find $dir -type f -iname '*.mp3' | sort -n | while read file; do
    mv "$file" "$dir/$(printf %0${len}d $n)_${mid}_$N.mp3"
    (( n++ ))
done
