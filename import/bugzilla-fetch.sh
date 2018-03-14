#!/bin/bash
set -euo pipefail

lastbug=18607

batchsize=1000

rm -rf pages
mkdir pages

bug=1
page=1
pages=()
while [[ $bug -lt $lastbug ]]
do
	printf "Downloading page %s\n" "$page"

	data='ctype=xml&'$(seq --format='id=%g' --separator='&' $bug $((bug+batchsize-1)))
	curl -o pages/$page.xml --data "$data" https://issues.dlang.org/show_bug.cgi

	pages+=($page)

	bug=$((bug+batchsize))
	page=$((page+1))
done

sed -e '/<bug>/,$d' pages/1.xml > out.xml
for page in "${pages[@]}"
do
	printf "Merging page %s\n" "$page" 1>&2
	sed -n -e '/<bug>/,$p' "pages/$page.xml" | tac | sed -n -e '/<\/bug>/,$p' | tac >> out.xml
done
tac pages/1.xml | sed -e '/<\/bug>/,$d' | tac >> out.xml
