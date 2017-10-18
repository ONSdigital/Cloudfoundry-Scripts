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
. "$BASE_DIR/common-bosh-login.sh"

[ -z "$RELEASE_DIR" ] && FATAL 'No release dir provided'
[ -d "$RELEASE_DIR" ] || FATAL "Bosh release directory does not exist: $RELEASE_DIR"

cd "$RELEASE_DIR"

# Ensure required dirs & files exist
[ -d "config" ] || mkdir config
[ -f config/blobs.yml ] || touch config/blobs.yml

if [ -n "$3" ]; then
	shift 2

	for _s in $@; do
		filename="`basename "$_s"`"

		"$BOSH_CLI" add-blob "$_s" "$RELEASE_BLOB_DESTINATION/$filename"
	done
fi

"$BOSH_CLI" create-release --force

"$BOSH_CLI" upload-release --rebase
