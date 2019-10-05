#!/bin/bash -e

find -name split -exec rm -rf '{}' \; -prune

for d in $(find -type d -links 2); do
# for d in $(find a -type d -links 2); do
   pushd $d > /dev/null
   rm -rf split
   mp3splt -t 10.0 -a -d split *.mp3
   rm -f *.mp3
   mv split/* .
   rm -rf split
   popd > /dev/null
   ~/bin/rename.sh $d
done
