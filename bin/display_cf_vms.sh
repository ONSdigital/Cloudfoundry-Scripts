#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

DEPLOYMENT_NAME="$1"
# vitals|failing
OPTION="${2:-vitals}"
INTERVAL="${3:-5}"
OUTPUT_TYPE="${4:-tty}"

[ x"$OUTPUT_TYPE" = x"tty" -o x"$OUTPUT_TYPE" = x"json" ] || FATAL "Incorrect output type. Valid types: tty or json"

#
DEPLOYMENT_FOLDER="$DEPLOYMENT_DIRECTORY/$DEPLOYMENT_NAME"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_FOLDER" ] || FATAL "Deployment does not exist '$DEPLOYMENT_FOLDER'"

eval export `prefix_vars "$DEPLOYMENT_FOLDER/bosh-config.sh"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
export BOSH_CA_CERT

case "$OPTION" in
	v*|vitals)
		BOSH_OPTS="--vitals"
		;;
	f*|failing)
		BOSH_OPTS="--ps -f"
		;;
	*)
		FATAL "Unknown option '$OPTION'"
		;;
esac

watch -tn "$INTERVAL" "'$BOSH' instances $BOSH_OPTS --$OUTPUT_TYPE"
