#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"


DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
# vitals|failing
OPTION="${2:-$OPTION}"
INTERVAL="${3:-$INTERVAL}"
OUTPUT_TYPE="${4:-$OUTPUT_TYPE}"

[ -z "$OPTION" ] && OPTION='vitals'
[ -z "$INTERVAL" ] && INTERVAL='5'
[ -z "$OUTPUT_TYPE" ] && OUTPUT_TYPE='tty'

. "$BASE_DIR/common.sh"

[ x"$OUTPUT_TYPE" = x"tty" -o x"$OUTPUT_TYPE" = x"json" ] || FATAL "Incorrect output type. Valid types: tty or json"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist '$DEPLOYMENT_DIR'"
[ -f "$BOSH_DIRECTOR_CONFIG" ] || FATAL "Bosh Director configuration file does not exist: $BOSH_DIRECTOR_CONFIG"

eval export `prefix_vars "$BOSH_DIRECTOR_CONFIG"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
export BOSH_CA_CERT

case "$OPTION" in
	v*|vitals|--vitals)
		BOSH_OPTS="--vitals"
		;;
	f*|failing|--failing)
		BOSH_OPTS="--ps -f"
		;;
	*)
		FATAL "Unknown option '$OPTION'"
		;;
esac

watch -tn "$INTERVAL" "'$BOSH_CLI' instances $BOSH_OPTS --$OUTPUT_TYPE"
