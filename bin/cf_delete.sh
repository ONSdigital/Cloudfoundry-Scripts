#!/bin/sh
#
# Very simplified CF delete - there is a more full fat CF suite within the CF repo
# This is here so we can bootstrap/test enough of CF to make sure things work
#
# Variables:
#	DEPLOYMENT_NAME=[Deployment name]
#	CF_APP=[Cloudfoundry application]
#
# Parameters:
#	[Deployment name]
#	[Cloudfoundry application]
#
# Requires:
#	common.sh
#	bosh-env.sh


set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="${1:-$CF_DEPLOYMENT}"
CF_APP="${2:-$CF_APP}"

NO_SKIP_SSL_VALIDATION="$3"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/bosh-env.sh"

[ -z "$CF_APP" ] && FATAL 'No application name provided'

"$CF_CLI" target -o "$CF_ORG" -s "$CF_SPACE"

INFO 'Checking if application exists'
if "$CF_CLI" app "$CF_APP" >/dev/null 2>&1; then
	INFO "Deleting application: $CF_APP"
	"$CF_CLI" delete -r -f $CF_APP
else
	INFO "Application does not exist: $CF_APP"
fi

