#!/bin/bash
set -euo pipefail

# Load configuration
if [[ ! -f secrets.sh ]]
then
	echo 'Creating secrets.sh from secrets.sample.sh - you may want to edit this'
	cp secrets.sample.sh secrets.sh
fi
source secrets.sh

# Prepare configuration
if $production
then
	src_dir=~/www
else
	src_dir=src
	urlbase=http://127.0.0.1:$port/
fi

# Install dependencies
# (These are likely incomplete)
source /etc/lsb-release
case $DISTRIB_ID in
	Arch)
		packages=(
			cpanminus
			mariadb
			mariadb-libs # provides mysql_config, needed by DBD::mysql
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

if ! $production
then
	# Create MySQL data dir
	test -d mysql || mysql_install_db --basedir=/usr --datadir=./mysql

	# Start MySQL server (hit Ctrl+\ to quit gracefully)
	test -e mysql/mysql.sock || ( ${TERMINAL-xterm} -e ./mysql-server.sh & sleep 1 )

	# Create database
	test -d mysql/dbugs || mysql --socket=mysql/mysql.sock <<<'CREATE DATABASE dbugs;'
fi

# Get code
test -d $src_dir || git clone --branch=dlang https://github.com/CyberShadow/bmo src

# Create initial perl environment
test -f $src_dir/local/lib/perl5/local/lib.pm || cpanm --local-lib=$src_dir/local local::lib

# Set up perl environment
eval "$(perl -I $src_dir/local/lib/perl5/ -Mlocal::lib=$src_dir/local)"

# Install checksetup dependencies
test -d $src_dir/local/lib/perl5/ExtUtils/MakeMaker || cpanm ExtUtils::MakeMaker

# Create initial parameters
mkdir -p $src_dir/data
if [[ ! -f $src_dir/data/params ]]
then
	if [[ -f .configured ]]
	then
		# The params file got deleted for some reason - we must reconfigure
		echo 'Configured previously but params file gone - reconfiguring, but consider starting from scratch'
		read -rp 'Press Enter to continue... '
		rm .configured
	fi

	cat > $src_dir/data/params <<EOF
%param = (
           'user_info_class' => 'GitHubAuth,CGI',
           'user_verify_class' => 'GitHubAuth,DB',
           'github_client_id' => '$github_client_id',
           'github_client_secret' => '$github_client_secret',
           'insidergroup' => 'admin', # fixes 500 on /enter_bug.cgi when logged in
           'timetrackinggroup' => '', # Disable time tracking fields
           'docs_urlbase' => 'https://bmo.readthedocs.io/%lang%/latest/',
           'utf8' => 1,
         );
EOF
fi

meta=$PWD # path to this directory

# Configure Bugzilla
if [[ ! -f .configured ]]
then
	(
		cd $src_dir
		if $production
		then
			./checksetup.pl --cpanm='all notest -oracle -pg -mod_perl' --default-localconfig /dev/stdin <<EOF
\$answer{'webservergroup'} = '';
\$answer{'db_driver'} = 'mysql';
\$answer{'db_host'}   = '';
\$answer{'db_name'}   = '$db_name';
\$answer{'db_user'}   = '$db_user';
\$answer{'db_pass'}   = '$db_pass';

\$answer{'urlbase'} = '$urlbase';
\$answer{'canonical_urlbase'} = 'https://issues.dlang.org/';

\$answer{'ADMIN_EMAIL'} = '$admin_email';
\$answer{'ADMIN_PASSWORD'} = '$admin_password';
\$answer{'ADMIN_REALNAME'} = '$admin_realname';
EOF
		else
			./checksetup.pl --cpanm='all notest -oracle -pg -mod_perl' --default-localconfig /dev/stdin <<EOF
\$answer{'webservergroup'} = '';
\$answer{'db_driver'} = 'mysql';
\$answer{'db_host'}   = '';
\$answer{'db_sock'}   = '$meta/mysql/mysql.sock';
\$answer{'db_port'}   = 0;
\$answer{'db_name'}   = 'dbugs';
\$answer{'db_user'}   = '$USER';
\$answer{'db_pass'}   = '';

\$answer{'urlbase'} = '$urlbase';
\$answer{'canonical_urlbase'} = 'https://issues.dlang.org/';

\$answer{'ADMIN_EMAIL'} = '$admin_email';
\$answer{'ADMIN_PASSWORD'} = '$admin_password';
\$answer{'ADMIN_REALNAME'} = '$admin_realname';
EOF
		fi

		"$meta"/generate_dlang_data.pl
	)
	touch .configured
fi

# Start Apache

if ! $production
then
	(
		cd "$src_dir"
		${TERMINAL-xterm} -e "./bugzilla.pl" daemon -l "http://${listen_addr:-*}:${port}" &
	)
	sleep 1
fi

# Check web server
( cd $src_dir ; ./testserver.pl "$urlbase" )

# Done
printf '\n\n'
printf 'All set up! Go to %s to access Bugzilla.\n' "$urlbase"
printf 'You can log in with %s / %s\n' "$admin_email" "$admin_password"
