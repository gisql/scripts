#!/bin/bash

for i in $(find -name '*.info'); do
	unset ALBUM
	unset TITLE
	unset YEAR
	unset COMMENT
	. $i
	reader=$(sed 's/Read by //g' <<< $COMMENT)

	dname=$(dirname $i)
	pushd $dname > /dev/null
	if [[ -z $ALBUM ]]; then
		~/bin/tags.sh "$TITLE" "$ARTIST" "$reader" $YEAR
	else
		~/bin/tags.sh "$TITLE" "$ARTIST" "$reader" $YEAR "$ALBUM"
	fi
	popd > /dev/null
done
