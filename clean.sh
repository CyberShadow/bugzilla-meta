#!/bin/bash
set -eu

dir=old/$(date +%s)
mkdir -p "$dir"
if [[ -e mysql/mysql.sock ]]
then
	mysqldump --socket=mysql/mysql.sock --user=root dbugs > "$dir"/db.sql
	killall mysqld
fi

rm -rf mysql
for f in $(git -C src clean -ndx | cut -c 14- | grep -vFx local/) ; do d=$(dirname "$f") ; mkdir -p "$dir/src/$d" ; mv "src/$f" "$dir/src/$d/" ; done
rm -f .configured
