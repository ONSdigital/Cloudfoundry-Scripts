#!/bin/sh
#
# Run 'bosh create-release' and 'bosh upload-release' to create and upload the given release
#

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
RELEASE_DIR="${2:-$RELEASE_DIR}"

RELEASE_BLOB_DESTINATION="${RELEASE_BLOB_DESTINATION:-blobs}"

. "$BASE_DIR/common.sh"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -z "$RELEASE_DIR" ] && FATAL 'No release dir provided'

[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist: $DEPLOYMENT_DIR"
[ -f "$BOSH_DIRECTOR_CONFIG" ] || FATAL "Bosh config does not exist: $BOSH_DIRECTOR_CONFIG"
[ -d "$RELEASE_DIR" ] || FATAL "Bosh release directory does not exist: $RELEASE_DIR"

eval export `prefix_vars "$BOSH_DIRECTOR_CONFIG"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"

export BOSH_CA_CERT

INFO "Pointing Bosh at deployed Bosh: $BOSH_ENVIRONMENT"
"$BOSH" alias-env -e "$BOSH_ENVIRONMENT" "$BOSH_ENVIRONMENT" >&2

INFO 'Attempting to login'
"$BOSH" log-in >&2

cd "$RELEASE_DIR"

# Ensure required dirs & files exist
[ -d "config" ] || mkdir config
[ -f config/blobs.yml ] || touch config/blobs.yml

if [ -n "$3" ]; then
	shift 2

	for _s in $@; do
		filename="`basename "$_s"`"

		"$BOSH" add-blob "$_s" "$RELEASE_BLOB_DESTINATION/$filename"
	done
fi

"$BOSH" create-release --force

"$BOSH" upload-release --rebase 
