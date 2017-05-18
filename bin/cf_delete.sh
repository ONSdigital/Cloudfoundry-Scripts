#!/bin/sh
#
# Very simplified CF delete - there is a more full fat CF suite within the CF repo
# This is here so we can bootstrap/test enough of CF to make sure things work
# 

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/bosh-env.sh"

CF_APP="$1"
CF_SPACE="${2:-Test}"
CF_ORG="${3:-$organisation}"

NO_SKIP_SSL_VALIDATION="$5"

[ -z "$CF_APP" ] && FATAL 'No application name provided'

"$CF" target -o "$CF_ORG" -s "$CF_SPACE"

INFO 'Checking if application exists'
if "$CF" app "$CF_APP" >/dev/null 2>&1; then
	INFO "Deleting application: $CF_APP"
	"$CF" delete -r -f $CF_APP
else
	INFO "Application does not exist: $CF_APP"	
fi

