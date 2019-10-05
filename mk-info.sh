#!/bin/bash

find . -type d -links 2 | while read d; do
	[[ $d =~ ' ' ]] && continue
	pushd $d > /dev/null
	nfo="$(basename $d | sed 's/^[0-9_]*//g').info"
	example=$(ls -1 *.mp3 | sort -rn | head -1)
	echo "Creating $nfo"
	fname=$(realpath $example)

	echo -ne "#\n#  @(#)  $nfo\n#\n\n" > $nfo
	echo -ne "# Based on $fname\n\n" >> $nfo
	mp3info -p "TITLE='%t'\nARTIST='%a'\nCOMMENT='%c'\nYEAR='%y'\nALBUM='%l'\n" $example \
		| sed 's/^\(TITLE=.*\) [0-9][0-9]*\/[0-9]*\(.\)$/\1\2/g' \
		| sort -u >> $nfo

	dname=$(dirname $fname)
	echo -ne "\n\n# Additional Information\n" >> $nfo
	mpegV=$(printf "%.1f" $(mp3info -p %v $example))
	mp3info -p "INFO='MPEG $mpegV layer %L, %r kbit/s, %qkHz %o'\n" $example >> $nfo
	echo "TOTAL_SIZE=$(du -c $dname/*.mp3 | tail -1 | sed 's/[^0-9]//g')" >> $nfo
	echo "TOTAL_TIME=$(mp3info -p '%S\n' $dname/*.mp3 | awk '{ sum += $1 } END { print sum }')" >> $nfo
	echo "TOTAL_COUNT=$(find $dname -name '*.mp3' | wc -l)" >> $nfo

	popd > /dev/null
done
