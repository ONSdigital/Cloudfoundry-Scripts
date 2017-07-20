#!/bin/sh
#
# Work-in-progress
#
# If things really break you can purge and then delete:
#
# cf purge-service-offering $SERVICE_NAME
# cf delete-service-broker $SERVICE_NAME

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="$1"
SERVICE_NAME="${2:-$SERVICE_NAME}"
SERVICE_USERNAME="${3:-$SERVICE_USERNAME}"
SERVICE_PASSWORD="${4:-$SERVICE_PASSWORD}"
SERVICE_URL="${5:-$SERVICE_URL}"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/bosh-env.sh"

installed_bin cf

eval export `prefix_vars "$BOSH_DIRECTOR_CONFIG"`
eval export `prefix_vars "$CF_CREDENTIALS"`

[ -z "$SERVICE_URL" ] && FATAL 'Not enough parameters'

[ -n "$DONT_SKIP_SSL_VALIDATION" ] || CF_EXTRA_OPTS='--skip-ssl-validation'

if "$CF" service-brokers | grep -Eq "^$SERVICE_URL$"; then
	[ -n "$IGNORE_EXISTING" ] && LOG_LEVEL='WARN' || LOG_LEVEL='FATAL'

	$LOG_LEVEL "Service broker '$SERVICE_NAME' exists"

	exit 0
fi

if [ -z "$NO_LOGIN" ]; then
	INFO "Setting API target as $api_dns"
	"$CF" api "$api_dns" "$CF_EXTRA_OPTS"

	INFO "Logging in as $CF_ADMIN_USERNAME"
	"$CF" login -u "$CF_ADMIN_USERNAME" -p "$CF_ADMIN_PASSWORD" -s "$SERVICES_SPACE" "$CF_EXTRA_OPTS" 
else
	"$CF" target -s "$SERVICES_SPACE"
fi

INFO "Creating service broker: $SERVICE_NAME"
"$CF" create-service-broker "$SERVICE_NAME" "$SERVICE_USERNAME" "$SERVICE_PASSWORD" "$SERVICE_URL"

INFO "Enabling service broker: $SERVICE_NAME"
"$CF" enable-service-access "$SERVICE_NAME"
