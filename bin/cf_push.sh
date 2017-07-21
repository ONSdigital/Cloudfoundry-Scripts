#!/bin/sh
#
# Very simplified CF push - there is a more full fat CF suite within the CF repo
# This is here so we can bootstrap/test enough of CF to make sure things work
# 
# To be called from another script

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="$1"
APP_NAME="$2"
CF_ORG="${3:-$organisation}"
CF_SPACE="${4:-Test}"

if [ -z "$APP_NAME" ]; then
	[ -f manifest.yml ] || FATAL 'Application manifest does not exist'

	INFO 'Determining application name from manifest.yml'
	APP_NAME="`awk '/^- name: /{ print $NF }' manifest.yml`"

	[ -z "$APP_NAME" ] && FATAL 'Unable to determine application name from manifest.yml'
fi

"$CF" target -o "$CF_ORG" -s "$CF_SPACE"

if "$CF" app "$APP_NAME" >/dev/null 2>&1; then
	WARN "Deleting existing app: $APP_NAME"

	"$CF" delete -f "$APP_NAME"
fi

"$CF" push "$APP_NAME" || FAILED=1

if [ -n "$FAILED" ]; then
	"$CF" logs "$APP_NAME" --recent

	FATAL 'Application failed to deploy'
fi

# Should really check if this is a web app or a TCP route
APP_URL="`cf_app_url \"$APP_NAME\"`"

if [ -z "$APP_URL" ]; then
	WARN 'Unable to determine application URL - cannot perform health check'
	exit 0
fi

INFO "Testing https://$APP_URL"
curl -sk "https://$APP_URL" | grep -q "404 Not Found: Requested route ('https://$APP_URL') does not exist." && FATAL "Application does not appear to exist on https://$APP_URL" || :
INFO "Successfully deployed https://$APP_URL"
