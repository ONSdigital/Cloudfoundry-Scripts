#!/bin/sh
#
# Run 'bosh create-release' and 'bosh upload-release' to create and upload the given release
#

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
RELEASE_NAME="${2:-$RELEASE_NAME}"

RELEASE_BLOB_DESTINATION="${RELEASE_BLOB_DESTINATION:-blobs}"

. "$BASE_DIR/common.sh"

[ -z "$RELEASE_NAME" ] && FATAL 'No release name provided'
[ -d "$RELEASE_NAME" ] || FATAL "Bosh release directory does not exist: $RELEASE_NAME"

cd "$RELEASE_NAME"

# Ensure required dirs & files exist
[ -d "config" ] || mkdir config
[ -f config/blobs.yml ] || touch config/blobs.yml

if [ -n "$2" ]; then
	shift 2

	for _s in $@; do
		filename="`basename "$_s"`"

		INFO "Adding Blob: $_s"
		"$BOSH_CLI" add-blob "$_s" "$RELEASE_BLOB_DESTINATION/$filename"
	done
fi

INFO "Creating release: $RELEASE_NAME"
"$BOSH_CLI" create-release --force --tarball "$RELEASE_NAME.tgz"
