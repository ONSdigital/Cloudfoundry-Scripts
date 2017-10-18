#!/bin/sh
#
# Horrible....
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

DATABASE_ADMIN_NAME='postgres'
DATABASE_ADMIN_USERNAME='postgres'

# [[ is not supported by the Debian shell (dash)
#while [[ $# -gt 1 ]]; do
for i in `seq 1 $#`; do
	case "$1" in
		--admin-database)
			ADMIN_DATABASE_NAME="$2"
			;;
		--admin-username)
			ADMIN_USERNAME="$2"
			;;
		--admin-password)
			ADMIN_PASSWORD="$2"
			;;
		--postgres-hostname|--postgresql-hostname)
			POSTGRESQL_HOSTNAME="$2"
			;;
		--postgres-port|--postgresql-port)
			POSTGRESQL_PORT="$2"
			;;
		--new-database-name)
			NEW_DATABASE_NAME="$2"
			;;
		--new-database-username)
			NEW_DATABASE_USERNAME="$2"
			;;
		--new-database-password)
			NEW_DATABASE_PASSWORD="$2"
			;;
		--jump-userhost)
			JUMP_USERHOST="$2"
			;;
		--ssh-key)
			SSH_KEY="$2"
			;;
		--extensions)
			# CSV list
			EXTENSIONS="$2"
			;;
		*)
			FATAL "Unknown parameter: '$1'"
	esac

	[ -n "$2" ] && shift 2
done

for i in ADMIN_USERNAME NEW_DATABASE_NAME; do
	eval var="\$$i"

	[ -z "$var" -o x"$var" = x'$' ] && FATAL "Missing parameter critical: $i"
done

if [ -n "$SSH_KEY" -a -f "$SSH_KEY" ]; then
	stat --format '%a' "$SSH_KEY" | grep -Eq '^0?[46]00' || chmod 0600 "$SSH_KEY"

elif [ -n "$SSH_KEY" ]; then
	unset SSH_KEY

fi

# Do we need to jump to another host before doing anything?
if [ -n "$JUMP_USERHOST" -a -n "$SSH_KEY" ]; then
	PRE_COMMAND_SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -ti '$SSH_KEY' '$JUMP_USERHOST' <<EOF_SSH"
	PRE_COMMAND_END='EOF_SSH'

elif [ -n "$JUMP_USERHOST" ]; then
	PRE_COMMAND_SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t '$JUMP_USERHOST' <<EOF_SSH"
	PRE_COMMAND_END='EOF_SSH'
fi

# Set our DB password - insecurely
if [ -n "$ADMIN_PASSWORD" ]; then
	VARS="PGPASSWORD='$ADMIN_PASSWORD'"
fi

if [ -n "$POSTGRESQL_HOSTNAME" ]; then
	PSQL_HOST_OPT="-h'$POSTGRESQL_HOSTNAME'"
fi

if [ -n "$POSTGRESQL_PORT" ]; then
	PSQL_PORT_OPT="-p'$POSTGRESQL_PORT'"
fi

if [ -n "$ADMIN_DATABASE" ]; then
	PSQL_ADMIN_DATABASE="'$ADMIN_DATABASE'"
fi
PSQL_CREATE_DATABASE="CREATE DATABASE :new_database_name OWNER :new_database_username"

if [ -n "$NEW_DATABASE_USERNAME" ]; then
	sh <<EOF_PRE
$PRE_COMMAND_SSH
if ! which psql >/dev/null 2>&1; then
	[ -d "/var/vcap" ] && PSQL="\\\`find /var/vcap -name \\\*psql 2>/dev/null | head -n1\\\`"
else
	PSQL='psql'
fi
$VARS "\\\$PSQL" -U"$ADMIN_USERNAME" $PSQL_HOST_OPT $PSQL_PORT_OPT -v new_database_name="$NEW_DATABASE_NAME" -v new_databse_username="$NEW_DATABASE_USERNAME" -v new_database_password="'$NEW_DATABASE_PASSWORD'" <<EOF_PSQL
CREATE USER :new_database_username ENCRYPTED PASSWORD :new_database_password;
CREATE DATABASE :new_database_name OWNER :new_database_username;
EOF_PSQL
$PRE_COMMAND_END
EOF_PRE
else
	shx <<EOF_PRE
$PRE_COMMAND_SSH
if ! which psql >/dev/null 2>&1; then
	[ -d "/var/vcap" ] && PSQL="\\\`find /var/vcap -name \\\*psql 2>/dev/null | head -n1\\\`"
else
	PSQL='psql'
fi
$VARS "\\\$PSQL" -U"$ADMIN_USERNAME" $PSQL_HOST_OPT $PSQL_PORT_OPT -v new_database_name="$NEW_DATABASE_NAME" <<EOF_PSQL
CREATE DATABASE :new_database_name;
EOF_PSQL
$PRE_COMMAND_END
EOF_PRE
fi

if [ -n "$EXTENSIONS" ]; then
	OLDIFS="$IFS"
	IFS=','
	for ext in $EXTENSIONS; do
		shx <<EOF_PRE
$PRE_COMMAND_SSH
if ! which psql >/dev/null 2>&1; then
	[ -d "/var/vcap" ] && PSQL="\\\`find /var/vcap -name \\\*psql 2>/dev/null | head -n1\\\`"
else
	PSQL='psql'
fi
$VARS "\\\$PSQL" -U"$ADMIN_USERNAME" $PSQL_HOST_OPT $PSQL_PORT_OPT -v extension="$ext" -v new_database_name="$NEW_DATABASE_NAME" <<EOF_PSQL
\c :new_database_name
CREATE EXTENSION :extension IF NOT EXISTS;
EOF_PSQL
$PRE_COMMAND_END
EOF_PRE
	done

	IFS="$OLDIFS"
fi
