#!/bin/bash
set -eu

test | -e mysql/mysql.sock || killall mysqld
rm -rf mysql
rm -f src/localconfig .configured
