production=false

admin_email=dbugs@example.com
admin_realname=Administrator
admin_password=bzJ4GXaL58

if $production
then
	urlbase=https://issues.dlang.org/
	db_name=dbugs
	db_user=dbugs
	# db_pass=abcdefghij
else
	listen_addr=127.0.0.1
	port=8001
fi

# GitHub Auth data
github_client_id= # 0123456789abcdef0123
github_client_secret= # 0123456789abcdef0123456789abcdef01234567
