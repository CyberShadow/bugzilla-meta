#!/bin/bash
set -euo pipefail

# Install dependencies
# (These are likely incomplete)
source /etc/lsb-release
case $DISTRIB_ID in
	Arch)
		packages=(
			cpanminus
			mariadb
			libmariadbclient # provides mysql_config, needed by DBD::mysql
			patchutils # "difference between two patches"
		)
		missing=($(comm -23 <(printf '%s\n' "${packages[@]}" | sort) <(pacman -Qq | sort)))
		[[ ${#missing[@]} -eq 0 ]] || sudo pacman -S "${missing[@]}"
		;;
	Ubuntu)
		packages=(
			cpanminus
		)
		missing=($(comm -23 <(printf '%s\n' "${packages[@]}" | sort) <(dpkg-query -W -f='${Package} ${Status}\n' | grep 'install ok installed$' | cut -d ' ' -f 1 | sort -u)))
		[[ ${#missing[@]} -eq 0 ]] || sudo apt install "${missing[@]}"
		;;
esac

# Create MySQL data dir
test -d mysql || mysql_install_db --basedir=/usr --datadir=./mysql

# Start MySQL server (hit Ctrl+\ to quit gracefully)
test -e mysql/mysql.sock || ( ${TERMINAL-xterm} -e ./mysql-server.sh & sleep 1 )

# Create database
test -d mysql/dbugs || mysql --socket=mysql/mysql.sock --user=root <<<'CREATE DATABASE dbugs;'

# Get code
test -d src || git clone --branch=dlang https://github.com/CyberShadow/bmo src

# Create initial perl environment
test -f src/local/lib/perl5/local/lib.pm || cpanm --local-lib=src/local local::lib

# Set up perl environment
eval "$(perl -I src/local/lib/perl5/ -Mlocal::lib=src/local)"

# Configure Bugzilla
if [[ ! -f .configured ]]
then
	(
		cd src
		./checksetup.pl --cpanm='all notest -oracle -pg -mod_perl' --default-localconfig /dev/stdin <<EOF
\$answer{'webservergroup'}   = '';
\$answer{'db_host'}   = '';
\$answer{'db_driver'} = 'mysql';
\$answer{'db_sock'}   = '$PWD/../mysql/mysql.sock';
\$answer{'db_port'}   = 0;
\$answer{'db_name'}   = 'dbugs';
\$answer{'db_user'}   = 'root';
\$answer{'db_pass'}   = '';

\$answer{'urlbase'} = 'http://localhost/';

\$answer{'ADMIN_EMAIL'} = 'dbugs@example.com';
\$answer{'ADMIN_PASSWORD'} = 'bzJ4GXaL58';
\$answer{'ADMIN_REALNAME'} = 'Administrator';
EOF
	)
	touch .configured
fi

# Start Apache

if ! [[ -f apache2/httpd.pid && -d "/proc/$(cat apache2/httpd.pid)" && "$(readlink "/proc/$(cat apache2/httpd.pid)/exe")" == "$(realpath "$(command -v httpd)")" ]]
then
	${TERMINAL-xterm} -e httpd -f "$PWD/apache2/httpd.conf" -X  &
	sleep 1
fi

# Check web server
( cd src ; ./testserver.pl http://127.0.0.1:8001/ )

# Done
printf '\n\n'
printf 'All set up! Go to http://127.0.0.1:8001/ to access Bugzilla.\n'
printf 'You can log in with dbugs@example.com / bzJ4GXaL58\n'
