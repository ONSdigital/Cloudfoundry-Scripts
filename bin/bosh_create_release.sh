#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="$1"
RELEASE_DIR="$2"
RELEASE_BLOB_SOURCE="$3"
RELEASE_BLOB_DESTINATION="$4"

. "$BASE_DIR/common.sh"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -z "$RELEASE_DIR" ] && FATAL 'No release dir provided'
[ -z "$RELEASE_BLOB_DESTINATION" ] && WARN 'No blob desination provided'

[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist: $DEPLOYMENT_DIR"
[ -f "$BOSH_DIRECTOR_CONFIG" ] || FATAL "Bosh config does not exist: $BOSH_DIRECTOR_CONFIG"
[ -d "$RELEASE_DIR" ] || FATAL "Bosh release directory does not exist: $RELEASE_DIR"

[ -z "$RELEASE_BLOB_DESTINATION" ] && RELEASE_BLOB_DESTINATION="`basename "$RELEASE_BLOB_SOURCE"`"

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

cd "$RELEASE_DIR"

[ -n "$RELEASE_BLOB_SOURCE" ] && "$BOSH" add-blob "$RELEASE_BLOB_SOURCE" "$RELEASE_BLOB_DESTINATION"

"$BOSH" create-release --force

"$BOSH" upload-release --rebase 
