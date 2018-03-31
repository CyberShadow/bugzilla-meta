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

if ! $production
then
	# Create MySQL data dir
	test -d mysql || mysql_install_db --basedir=/usr --datadir=./mysql

	# Start MySQL server (hit Ctrl+\ to quit gracefully)
	test -e mysql/mysql.sock || ( ${TERMINAL-xterm} -e ./mysql-server.sh & sleep 1 )

	# Create database
	test -d mysql/dbugs || mysql --socket=mysql/mysql.sock --user=root <<<'CREATE DATABASE dbugs;'
fi

# Get code
test -d $src_dir || git clone --branch=dlang https://github.com/CyberShadow/bmo src

# Create initial perl environment
test -f $src_dir/local/lib/perl5/local/lib.pm || cpanm --local-lib=$src_dir/local local::lib

# Set up perl environment
eval "$(perl -I $src_dir/local/lib/perl5/ -Mlocal::lib=$src_dir/local)"

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

\$answer{'ADMIN_EMAIL'} = '$admin_email';
\$answer{'ADMIN_PASSWORD'} = '$admin_password';
\$answer{'ADMIN_REALNAME'} = '$admin_realname';
EOF
		else
			./checksetup.pl --cpanm='all notest -oracle -pg -mod_perl' --default-localconfig /dev/stdin <<EOF
\$answer{'webservergroup'} = '';
\$answer{'db_driver'} = 'mysql';
\$answer{'db_host'}   = '';
\$answer{'db_sock'}   = '$PWD/../mysql/mysql.sock';
\$answer{'db_port'}   = 0;
\$answer{'db_name'}   = 'dbugs';
\$answer{'db_user'}   = 'root';
\$answer{'db_pass'}   = '';

\$answer{'urlbase'} = '$urlbase';

\$answer{'ADMIN_EMAIL'} = '$admin_email';
\$answer{'ADMIN_PASSWORD'} = '$admin_password';
\$answer{'ADMIN_REALNAME'} = '$admin_realname';
EOF
		fi
	)
	touch .configured
fi

# Start Apache

if ! $production
then
	if ! [[ -f apache2/httpd.pid && -d "/proc/$(cat apache2/httpd.pid)" && "$(readlink "/proc/$(cat apache2/httpd.pid)/exe")" == "$(realpath "$(command -v httpd)")" ]]
	then
		cat > apache2/httpd.conf <<EOF
ServerName 127.0.0.1
ServerAdmin root@localhost
PidFile \${PWD}/apache2/httpd.pid
Listen 127.0.0.1:$port

LoadModule access_compat_module modules/mod_access_compat.so
LoadModule alias_module modules/mod_alias.so
LoadModule authn_core_module modules/mod_authn_core.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule authz_host_module modules/mod_authz_host.so
LoadModule authz_user_module modules/mod_authz_user.so
# LoadModule autoindex_module modules/mod_autoindex.so
LoadModule cgi_module modules/mod_cgi.so
LoadModule dir_module modules/mod_dir.so
LoadModule headers_module modules/mod_headers.so
LoadModule log_config_module modules/mod_log_config.so
LoadModule mime_module modules/mod_mime.so
LoadModule unixd_module modules/mod_unixd.so
LoadModule mpm_prefork_module modules/mod_mpm_prefork.so
LoadModule remoteip_module modules/mod_remoteip.so
LoadModule rewrite_module modules/mod_rewrite.so

UseCanonicalName Off
<Directory />
    Options FollowSymLinks
    AllowOverride None
</Directory>
# AccessFileName .htaccess
<Files ~ "^\.ht">
    Order allow,deny
    Deny from all
    Satisfy All
</Files>
TypesConfig /etc/mime.types
DefaultType text/plain
# MIMEMagicFile conf/magic
HostnameLookups Off
ErrorLog /dev/stderr
TransferLog /dev/stdout
LogLevel warn
ServerSignature Off
AddDefaultCharset UTF-8

# Include /app/conf/env.conf

# PerlSwitches -wT
# PerlRequire /app/mod_perl.pl
DirectoryIndex index.cgi
DocumentRoot "\${PWD}/src"
<Directory "\${PWD}/src">
    AddHandler cgi-script .cgi
    Options +ExecCGI

    #Options -Indexes -FollowSymLinks
    Options -Indexes
    AllowOverride Limit FileInfo Indexes
    Order allow,deny
    Allow from all
</Directory>
EOF

		${TERMINAL-xterm} -e httpd -f "$PWD/apache2/httpd.conf" -X  &
		sleep 1
	fi
fi

# Check web server
( cd $src_dir ; ./testserver.pl "$urlbase" )

# Done
printf '\n\n'
printf 'All set up! Go to %s to access Bugzilla.\n' "$urlbase"
printf 'You can log in with %s / %s\n' "$admin_email" "$admin_password"
