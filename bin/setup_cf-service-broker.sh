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

. "$BASE_DIR/common.sh"
. "$BASE_DIR/common-cf.sh"
. "$BASE_DIR/bosh-env.sh"

eval export `prefix_vars "$DEPLOYMENT_FOLDER/bosh-config.sh"`
eval export `prefix_vars "$DEPLOYMENT_FOLDER/outputs.sh" RABBITMQ_`
eval export `prefix_vars "$DEPLOYMENT_FOLDER/passwords.sh" RABBITMQ_`
eval export `prefix_vars "$DEPLOYMENT_FOLDER/cf-credentials-admin.sh" RABBITMQ_`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
export BOSH_CA_CERT

SERVICE_NAME="${1:-$SERVICE_NAME}"
SERVICE_USERNAME="${2:-$SERVICE_USERNAME}"
SERVICE_PASSWORD="${3:-$SERVICE_PASSWORD}"
SERVICE_URL="${4:-$SERVICE_URL}"

[ -z "$SERVICE_URL" ] && FATAL 'Not enough parameters'

if "$CF" service-brokers | grep -Eq "^$SERVICE_URL$"; then
	[ -n "$IGNORE_EXISTING" ] && LOG_LEVEL='WARN' || LOG_LEVEL='FATAL'

	$LOG_LEVEL "Service broker '$SERVICE_NAME' exists"

	exit 0
fi

"$CF" create-service-broker "$SERVICE_NAME" "$SERVICE_USERNAME" "$SERVICE_PASSWORD" "$SERVICE_URL"

"$CF" enable-service-access "$SERVICE_NAME"
