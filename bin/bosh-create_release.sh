#!/bin/sh
#
# Run 'bosh create-release' and 'bosh upload-release' to create and upload the given release
#
# Variables:
#	RELEASE_NAME=[Release name]
#	RELEASE_DIR=[Release directory]
#
# Parameters:
#	[Release name]
#	[Release directory]
#
# Requires:
#	common.sh

set -e

BASE_DIR="`dirname \"$0\"`"

RELEASE_NAME="${1:-$RELEASE_NAME}"
RELEASE_DIR="${2:-${RELEASE_DIR:-$RELEASE_NAME}}"

. "$BASE_DIR/common.sh"
set -x
[ -z "$RELEASE_NAME" ] && FATAL 'No release name provided'
[ -d "$RELEASE_DIR" ] || FATAL "Bosh release directory does not exist: $RELEASE_NAME"

# Releases place their blobs under their own folder, so we can automatically add the right blobs
# to the right releases
[ -d "blobs/$RELEASE_NAME" ] && findpath BLOBS_DIR "blobs/$RELEASE_NAME"

cd "$RELEASE_DIR"

[ -f version.txt ] || echo "0.1.0" >version.txt

version="`cat version.txt`"

# Ensure required dirs & files exist
[ -d config ] || mkdir config
[ -f config/blobs.yml ] || touch config/blobs.yml

if [ -n "$BLOBS_DIR" ]; then
	[ -d blobs ] || mkdir -p blobs

	for _b in `ls "$BLOBS_DIR"`; do
		INFO ". adding $_b"
		"$BOSH_CLI" add-blob --tty "$BLOBS_DIR/$_b" "blobs/$_b"
	done
fi

INFO "Creating release: $RELEASE_NAME"
"$BOSH_CLI" create-release --tty --force --version="$version" --tarball "$RELEASE_NAME.tgz"
