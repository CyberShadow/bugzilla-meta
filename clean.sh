#!/bin/bash
set -eu

# Delete EVERYTHING.

source ./secrets.sh

if $production
then
	if [[ "$1" != NUKE-EVERYTHING ]]
	then
		echo 'Not destroying production data!'
		exit 1
	fi
fi

dir=old/$(date +%s)
mkdir -p "$dir"

if $production
then
	mysqldump --user="$db_user" --password="$db_pass" "$db_name" > "$dir"/db.sql

	(
		echo 'SET FOREIGN_KEY_CHECKS = 0;'
		mysql --user="$db_user" --password="$db_pass" "$db_name" <<<"SELECT concat('DROP TABLE IF EXISTS ', table_name, ';') AS '-- command' FROM information_schema.tables WHERE table_schema != 'information_schema';"
	) | mysql --user="$db_user" --password="$db_pass" "$db_name"
else
	if $production || [[ -e mysql/mysql.sock ]]
	then
		mysqldump --socket=mysql/mysql.sock --user="$db_user" --password="$db_pass" "$db_name" > "$dir"/db.sql
		killall mysqld
	fi

	rm -rf mysql
fi

if $production
then
        src_dir=~/www
else
        src_dir=src
fi

for f in $(git -C "$src_dir" clean -ndx | cut -c 14- | grep -vFx local/)
do
	d=$(dirname "$f")
	mkdir -p "$dir/src/$d"
	mv "$src_dir/$f" "$dir/src/$d/"
done

rm -f .configured
