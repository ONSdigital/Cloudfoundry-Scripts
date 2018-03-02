#!/bin/sh
#
# Run 'bosh create-release' and 'bosh upload-release' to create and upload the given release
#
# Variables:
#	RELEASE_NAME=[Release name]
#	RELEASE_DIR=[Release directory]
#	RELEASE_BLOB_SOURCE=[Release blob source]
#	RELEASE_BLOB_DESTINATION=[Release blob destination]
#
# Parameters:
#	[Release name]
#	[Release directory]
#	[Release blob source]
#	[Release blob destination]
#
# Requires:
#	common.sh

set -e

BASE_DIR="`dirname \"$0\"`"

RELEASE_NAME="${1:-$RELEASE_NAME}"
RELEASE_DIR="${2:-${RELEASE_DIR:-$RELEASE_NAME}}"

RELEASE_BLOB_DESTINATION="$RELEASE_DIR/blobs"

. "$BASE_DIR/common.sh"

[ -z "$RELEASE_NAME" ] && FATAL 'No release name provided'
[ -d "$RELEASE_DIR" ] || FATAL "Bosh release directory does not exist: $RELEASE_NAME"
[ -d "$RELEASE_BLOB_DESTINATION" ] || mkdir -p "$RELEASE_BLOB_DESTINATION"

# Releases place their blobs under their own folder, so we can automatically add the right blobs
# to the right releases
[ -d "blobs/$RELEASE_DIR" ] && findpath BLOBS_DIR "blobs/$RELEASE_DIR"

# Find the fullpath
findpath RELEASE_BLOB_DESTINATION "$RELEASE_BLOB_DESTINATION"

cd "$RELEASE_DIR"

[ -f version.txt ] || echo "0.1.0" >version.txt

version="`cat version.txt`"

# Ensure required dirs & files exist
[ -d config ] || mkdir config
[ -f config/blobs.yml ] || touch config/blobs.yml

if [ -n "$BLOBS_DIR" ]; then
	find "$BLOBS_DIR" -type f -exec sh -xc "echo '. adding {}'; '$BOSH_CLI' add-blob --tty '{}' '$RELEASE_BLOB_DESTINATION'" \;
fi

INFO "Creating release: $RELEASE_NAME"
"$BOSH_CLI" create-release --tty --force --version="$version" --tarball "$RELEASE_NAME.tgz"
