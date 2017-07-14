#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/bosh-env.sh"

eval export `prefix_vars "$DEPLOYMENT_FOLDER/passwords.sh"`

[ -f "$DEPLOYMENT_FOLDER/cf-credentials-admin.sh" ] && eval `prefix_vars "$DEPLOYMENT_FOLDER/cf-credentials-admin.sh"`

USERNAME="$1"
EMAIL="$2"
PASSWORD="$3"
DONT_SKIP_SSL_VALIDATION="$4"

UAA_ADMIN_USERNAME="${UAA_ADMIN_USERNAME:-admin}"

[ -z "$USERNAME" ] && FATAL 'No username provided'
[ -z "$EMAIL" ] && FATAL 'No email address supplied'


# Generate config if it doesn't exist, or if any of the values have changed
if [ ! -f "$DEPLOYMENT_FOLDER/cf-credentials-admin.sh" ] ||
	[ -n "$USERNAME" -a -n "$CF_ADMIN_USERNAME" -a x"$CF_ADMIN_USERNAME" != x"$USERNAME" ] ||
	[ -n "$EMAIL" -a -n "$CF_ADMIN_EMAIL" -a x"$CF_ADMIN_EMAIL" != x"$EMAIL" ] ||
	[ -n "$PASSWORD" -a -n "$CF_ADMIN_PASSWORD" -a x"$CF_ADMIN_PASSWORD" != x"$PASSWORD" ]; then

	# Ensure we have some sort of password
	[ -z "$PASSWORD" -o -z "$CF_ADMIN_PASSWORD" ] && NEW_PASSWORD="`generate_password`" ||  NEW_PASSWORD="${PASSWORD:-$CF_ADMIN_PASSWORD}"

	# We shouldn't generate this if it alread
	cat >"$DEPLOYMENT_FOLDER/cf-credentials-admin.sh" <<EOF
# Cloudfoundry credentials
CF_ADMIN_EMAIL='$EMAIL'
CF_ADMIN_USERNAME='$USERNAME'
CF_ADMIN_PASSWORD='$NEW_PASSWORD'
EOF

	CHANGES=1

	# Re-parse CF admin credentials
	eval `prefix_vars "$DEPLOYMENT_FOLDER/cf-credentials-admin.sh"`
fi

[ -n "$DONT_SKIP_SSL_VALIDATION" ] || UAA_EXTRA_OPTS='--skip-ssl-validation'

INFO "Targetting UAA: $uaa_dns"
uaac target "$uaa_dns" "$UAA_EXTRA_OPTS"

INFO "Obtaining initial $UAA_ADMIN_USERNAME user token"
uaac token client get "$UAA_ADMIN_USERNAME" -s "$uaa_admin_client_secret"

# Hmmm... there is a better way
if uaac user get "$CF_ADMIN_USERNAME" >/dev/null; then
	if [ -z "$CHANGES" ]; then
		WARN 'No changes to perform'

		exit 0
	fi

	INFO "Deleting existing '$CF_ADMIN_USERNAME' user"
	uaac user delete "$CF_ADMIN_USERNAME"
fi

INFO "Adding '$CF_ADMIN_USERNAME' with '$CF_ADMIN_EMAIL' email"
uaac user add "$CF_ADMIN_USERNAME" -p "$CF_ADMIN_PASSWORD" --emails "$CF_ADMIN_EMAIL"

INFO "Adding required persmissions to $CF_ADMIN_USERNAME"
uaac member add cloud_controller.admin "$CF_ADMIN_USERNAME"
uaac member add uaa.admin "$CF_ADMIN_USERNAME"
uaac member add scim.read "$CF_ADMIN_USERNAME"
uaac member add scim.write "$CF_ADMIN_USERNAME"
