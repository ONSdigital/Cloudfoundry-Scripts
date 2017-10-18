#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common-bosh.sh"

for i in `seq 0 9`; do
	# Check we have a valid entry
	"$BOSH_CLI" interprolate "$BOSH_FULL_MANIFEST_FILE" --path /properties/databases/roles | sed -re 's/: /=/g' || break

	# Pull in the values
	eval `"$BOSH_CLI" interprolate "$BOSH_FULL_MANIFEST_FILE" --path /properties/databases/roles | sed -re 's/: /=/g'`

	[ -n "$name" ] || FATAL 'Unable to find database role name'

	# We blindly assume we've been given a templated parameter
	password_varname="`echo "$password" | sed -re 's/\(+|\)+//g'`"

	real_password="\$$password_varname"

	[ -n "$real_password" -o x"$real_password" != x'$' ] && password_opt="--new-database-password '$real_password'"

	"$BOSH_CLI" interprolate "$BOSH_FULL_MANIFEST_FILE" --path "/properties/databases/databases/name=$name" || FATAL "Unable to find database section for $name"

	eval `"$BOSH_CLI" interprolate "$BOSH_FULL_MANIFEST_FILE" --path "/properties/databases/databases/name=$name"`

	[ x"$citext" = x"true" ] && extensions_opt="--extensions citext"

	sh <<EOF
"$BASE_DIR/create_postgresql_db.sh" --admin-username "$rds_apps_instance_username" --admin-password "$rds_apps_instance_password" \
	--postgres-hostname "$rds_apps_instance_address" --postgres-port "$rds_apps_instance_port" --new-database-name "$name" \
	$extensions_opt $password_opt \
	--ssh-key "$bosh_ssh_key_file" --jump-userhost "vcap@$director_dns"
EOF
done
