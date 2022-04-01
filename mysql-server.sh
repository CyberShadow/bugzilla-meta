#!/bin/bash
set -eu

# Run a local UNIX-socket-only MySQL instance
# Ran automatically by ./init.sh

echo 'MySQL server - Press Ctrl+\ to stop gracefully'
echo '=============================================='
echo ''

args=(
	mysqld
	--no-defaults
	--datadir=./mysql
	--socket=./mysql.sock
	--skip-networking
	--general-log
	--skip-log-bin
)

if [[ "$(mysqld --no-defaults --help --verbose)" == *--skip-innodb-read-only-compressed* ]] ; then
	args+=(--skip-innodb-read-only-compressed)
fi

exec "${args[@]}"
