#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="$1"
BACKUP_DESTINATION="${2:-.}"

. "$BASE_DIR/common.sh"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist '$DEPLOYMENT_DIR'"
[ -f "$BOSH_DIRECTOR_CONFIG" ] || FATAL "Bosh config does not exist: $BOSH_DIRECTOR_CONFIG"

shift

eval export `prefix_vars "$BOSH_DIRECTOR_CONFIG"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"

export BOSH_CA_CERT

[ -z "${GATEWAY_HOST:-$BOSH_ENVIRONMENT}" ] && FATAL 'No gateway host available'

INFO "Pointing Bosh at deployed Bosh: $BOSH_ENVIRONMENT"
"$BOSH" alias-env -e "$BOSH_ENVIRONMENT" "$BOSH_ENVIRONMENT"

INFO 'Attempting to login'
"$BOSH" log-in

# Bosh prints everything out to stdout, so we need 
for _e in `"$BOSH" errands | grep -E '^backup-'`; do
	"$BOSH" run-errand "$_e"
done

"$AWS" --profile "$AWS_PROFILE" s3 sync "s3://$backup_bucket_name/databases/" "$BACKUP_DESTINATION/"
