#!/bin/sh
#
# Creates an additional Cloudfoundry admin user, or updates an already added one
#
# Parameters:
#	Deployment Name
#	Username
#	Email
#	Password
#	Secret
#	[Dont Skip SSL Validation]

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="$1"
USERNAME="$2"
EMAIL="$3"
PASSWORD="$4"
SECRET="$5"
DONT_SKIP_SSL_VALIDATION="$6"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/bosh-env.sh"

[ -f "$CF_CREDENTIALS" ] && . "$CF_CREDENTIALS"

UAA_ADMIN_USERNAME="${UAA_ADMIN_USERNAME:-admin}"

[ -z "$USERNAME" ] && FATAL 'No username provided'
[ -z "$EMAIL" ] && FATAL 'No email address supplied'
[ -z "$CF_CREDENTIALS" ] && FATAL 'Unknown CF credentials filename'

INFO "$STORE_ACTION CF Admin Password"
UAA_ADMIN_CLIENT_SECRET="`"$BOSH_CLI" interpolate --no-color --var-errs --path='/uaa_admin_client_secret' "$BOSH_FULL_VARIABLES_STORE"`"

[ -z "$UAA_ADMIN_CLIENT_SECRET" ] && FATAL 'Unable to determine UAA admin client secret'

# Generate config if it does not exist, or if any of the values have changed
if [ ! -f "$CF_CREDENTIALS" ] ||
	[ -n "$USERNAME" -a -n "$CF_ADMIN_USERNAME" -a x"$CF_ADMIN_USERNAME" != x"$USERNAME" ] ||
	[ -n "$EMAIL" -a -n "$CF_ADMIN_EMAIL" -a x"$CF_ADMIN_EMAIL" != x"$EMAIL" ] ||
	[ -n "$PASSWORD" -a -n "$CF_ADMIN_PASSWORD" -a x"$CF_ADMIN_PASSWORD" != x"$PASSWORD" ] ||
	[ -n "$SECRET" -a -n "$CF_ADMIN_CLIENT_SECRET" -a x"$CF_ADMIN_CLIENT_SECRET" != x"$SECRET" ]; then

	# Ensure we have some sort of password
	[ -z "$PASSWORD" -o -z "$CF_ADMIN_PASSWORD" ] && NEW_PASSWORD="`generate_password`" || NEW_PASSWORD="${PASSWORD:-$CF_ADMIN_PASSWORD}"
	[ -z "$SECRET" -o -z "$CF_ADMIN_SECRET" ] && NEW_SECRET="`generate_password`" || NEW_SECRET="${SECRET:-$CF_ADMIN_SECRET}"

	# We should not generate this if it alread
	cat >"$CF_CREDENTIALS" <<EOF
# Cloudfoundry credentials
CF_ADMIN_EMAIL='$EMAIL'
CF_ADMIN_USERNAME='$USERNAME'
CF_ADMIN_PASSWORD='$NEW_PASSWORD'
CF_ADMIN_CLIENT_SECRET='$NEW_SECRET'
EOF

	# Re-parse CF admin credentials
	. "$CF_CREDENTIALS"

	NEW_CREDENTIALS=1
fi


[ -n "$DONT_SKIP_SSL_VALIDATION" ] || UAA_EXTRA_OPTS='--skip-ssl-validation'

INFO "Targetting UAA: $uaa_dns"
uaac target "$uaa_dns" "$UAA_EXTRA_OPTS"

INFO "Obtaining initial $UAA_ADMIN_USERNAME user token"
uaac token client get "$UAA_ADMIN_USERNAME" -s "$UAA_ADMIN_CLIENT_SECRET"

# Hmmm... there is a better way
if uaac user get "$CF_ADMIN_USERNAME" >/dev/null || uaac client get "$CF_ADMIN_USERNAME" >/dev/null ; then
	if [ -z "$NEW_CREDENTIALS" ]; then
		WARN 'No changes to perform'

		exit 0
	fi

	INFO "Deleting existing '$CF_ADMIN_USERNAME' user"
	uaac user delete "$CF_ADMIN_USERNAME"

	INFO "Deleting existing '$CF_ADMIN_USERNAME' client"
	uaac client delete "$CF_ADMIN_USERNAME"
fi

INFO "Adding '$CF_ADMIN_USERNAME' user with '$CF_ADMIN_EMAIL' email"
uaac user add "$CF_ADMIN_USERNAME" --password "$CF_ADMIN_PASSWORD" --emails "$CF_ADMIN_EMAIL"

INFO "Adding required persmissions to '$CF_ADMIN_USERNAME' user"
uaac member add cloud_controller.admin "$CF_ADMIN_USERNAME"
uaac member add uaa.admin "$CF_ADMIN_USERNAME"
uaac member add scim.read "$CF_ADMIN_USERNAME"
uaac member add scim.write "$CF_ADMIN_USERNAME"

# Is this correct?
INFO "Adding '$CF_ADMIN_USERNAME' client"
uaac client add "$CF_ADMIN_USERNAME" --secret "$CF_ADMIN_CLIENT_SECRET" \
	--authorized_grant_types client_credentials,refresh_token \
	--authorities cloud_controller.admin,uaa.admin,scim.read,scim.write
