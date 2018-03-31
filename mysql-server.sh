#!/bin/bash
set -eu

# Run a local UNIX-socket-only MySQL instance
# Ran automatically by ./init.sh

echo 'MySQL server - Press Ctrl+\ to stop gracefully'
echo '=============================================='
echo ''

mysqld \
	--datadir=./mysql \
	--socket=./mysql.sock \
	--skip-networking \
	--general-log \
	--skip-log-bin
