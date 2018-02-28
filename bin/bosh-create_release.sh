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

RELEASE_BLOB_DESTINATION="${RELEASE_BLOB_DESTINATION:-blobs}"

. "$BASE_DIR/common.sh"

# Export INFO() so we can run it under find, _date() is called by INFO()
export -f INFO _date

findpath BLOBS_DIR blobs

[ -z "$RELEASE_NAME" ] && FATAL 'No release name provided'
[ -d "$RELEASE_DIR" ] || FATAL "Bosh release directory does not exist: $RELEASE_NAME"

shift 1

cd "$RELEASE_DIR"

[ -f "version.txt" ] || echo "0.1.0" >version.txt

version="`cat version.txt`"

# Ensure required dirs & files exist
[ -d "config" ] || mkdir config
[ -f config/blobs.yml ] || touch config/blobs.yml

if [ -d blobs ]; then
	cd blobs

	INFO 'Adding blobs'
	find . -type f -exec sh -xc "pwd;INFO '. adding {}'; '$BOSH_CLI' add-blob --dir "$RELEASE_DIR" --tty '{}' '$RELEASE_BLOB_DESTINATION/{}'" \;
fi

INFO "Creating release: $RELEASE_NAME"
"$BOSH_CLI" create-release --tty --force --dir "$RELEASE_DIR" --version="$version" --tarball "$RELEASE_NAME.tgz"
