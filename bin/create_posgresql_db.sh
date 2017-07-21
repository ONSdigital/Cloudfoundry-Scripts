#!/bin/sh

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

DATABASE_ADMIN_NAME='postgres'
DATABASE_ADMIN_USERNAME='postgres'

for param in $@; do
	case "$param" in
		--admin-database)
			DATABASE_ADMIN_NAME="$2"
			;;
		--database-admin-username)
			DATABASE_ADMIN_USERNAME="$2"
			;;
		--database-admin-password)
			DATABASE_ADMIN_PASSWORD="$2"
			;;
		--database-hostname)
			DATABASE_HOSTNAME="$2"
			;;
		--database-port)
			DATABASE_PORT="$2"
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
		*)
			FATAL "Unknown parameter: '$param'"
	esac
done

for i in DATABASE_ADMIN_USERNAME NEW_DATABASE_NAME NEW_DATABASE_USERNAME NEW_DATABASE_PASSWORD; do
	eval var="\$$i"

	[ -z "$var" -o x"$var" = x'$' ] && FATAL "Missing parameter critical: $i"
done

if [ -n "$SSH_KEY" -a -f "$SSH_KEY" ]; then
	stat --format '%a' "$SSH_KEY" | grep -Eq '^0?[46]00' || chmod 0600 "$SSH_KEY"

elif [ -n "$SSH_KEY" ]; then
	unset SSH_KEY

fi

# Do we need to jump to another host before doing anything?
if [ -n "$JUMP_USERHOST" -n "$SSH_KEY" ]; then
	PRE_COMMAND_SSH="ssh -i '$SSH_KEY' '$JUMP_USERHOST' <<EOF_SSH"
	PRE_COMMAND_END='EOF_SSH'

elif [ -n "$JUMP_USERHOST" ]; then
	PRE_COMMAND_SSH="ssh '$JUMP_USERHOST' <<EOF_SSH"
	PRE_COMMAND_END='EOF_SSH'
fi

# Set our DB password - insecurely
if [ -n "$DATABASE_ADMIN_PASSWORD" ]; then
	VARS="PGPASSWORD='$PGPASSWORD'"
fi

if [ -n "$DATABASE_HOSTNAME" ]; then
	PSQL_HOST_OPT="-h'$DATABASE_HOSTNAME'"
fi

if [ -n "$DATABASE_PORT" ]; then
	PSQL_PORT_OPT="-p'$DATABASE_PORT'"
fi

if [ -n "$DATABASE_ADMIN_NAME" ]; then
	PSQL_PORT_DATABASE="'$DATABASE_ADMIN_NAME'"
fi

PSQL_CREATE_DATABASE="CREATE DATABASE :new_database_name OWNER :new_database_username"


sh <<EOF_PRE
$PRE_COMMAND_SSH
psql $PSQL_HOST_OPT $PSQL_PORT_OPT -P new_database_name="$NEW_DATABASE_NAME" -P new_databse_username="$NEW_DATABASE_USERNAME" -P new_database_password="'$NEW_DATABASE_PASSWORD'" <<EOF_PSQL
CREATE USER :new_database_username ENCRYPTED PASSWORD :new_database_password;
CREATE DATABASE :new_database_name OWNER :new_database_username;
EOF_PSQL
EOF_SSH
EOF_PRE
