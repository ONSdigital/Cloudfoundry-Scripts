#!/bin/sh
#
# Run 'bosh create-release' and 'bosh upload-release' to create and upload the given release
#

set -e

BASE_DIR="`dirname \"$0\"`"

RELEASE_NAME="${1:-$RELEASE_NAME}"
RELEASE_DIR="${2:-${RELEASE_DIR:-$RELEASE_NAME}}"

RELEASE_BLOB_SOURCE="${RELEASE_BLOB_SOURCE:-downloads}"
RELEASE_BLOB_DESTINATION="${RELEASE_BLOB_DESTINATION:-blobs}"

. "$BASE_DIR/common.sh"

[ -z "$RELEASE_NAME" ] && FATAL 'No release name provided'
[ -d "$RELEASE_DIR" ] || FATAL "Bosh release directory does not exist: $RELEASE_NAME"

shift 1

cd "$RELEASE_DIR"

# Ensure required dirs & files exist
[ -d "config" ] || mkdir config
[ -f config/blobs.yml ] || touch config/blobs.yml

if [ -d "$RELEASE_BLOB_SOURCE" ]; then
	# We blindy assume/hope that the files don't contain spaces
	for _s in "$RELEASE_BLOB_SOURCE/"*; do
		[ -f "$_s" ] || continue

		filename="`basename "$_s"`"

		INFO "Adding Blob: $_s"
		"$BOSH_CLI" add-blob --tty "$_s" "$RELEASE_BLOB_DESTINATION/$filename"
	done
fi

INFO "Creating release: $RELEASE_NAME"
"$BOSH_CLI" create-release --tty --force --tarball "$RELEASE_NAME.tgz"
