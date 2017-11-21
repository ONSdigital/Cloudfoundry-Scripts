#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
ORG_NAME="${2:-$organisation}"
SPACE_NAME="${3:-Test}"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/bosh-env.sh"

INFO 'Loading Bosh director config'
export_file_vars "$BOSH_DIRECTOR_CONFIG"
#export `grep -Evi '^#' "$PASSWORD_CONFIG_FILE"`
#export `grep -Evi '^#' "$CF_CREDENTIALS"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
export BOSH_CA_CERT

[ -z "$SPACE_NAME" ] && FATAL 'No space name provided'
[ -z "$ORG_NAME" ] && FATAL 'No organisation name provided'

if ! "$CF_CLI" org "$ORG_NAME" >/dev/null 2>&1; then
	# Add some intelligence to check existance of org & space
	INFO "Creating organisation $ORG_NAME"
	"$CF_CLI" create-org "$ORG_NAME"
else
	INFO "Organisation already created: $ORG_NAME"
fi

if ! "$CF_CLI" space "$SPACE_NAME" >/dev/null 2>&1; then
	# This seems to create the org
	INFO "Creating space $SPACE_NAME under $ORG_NAME"
	"$CF_CLI" create-space "$SPACE_NAME" -o "$ORG_NAME"
else
	INFO "Space already created: $SPACE_NAME"
fi

"$CF_CLI" target -o "$ORG_NAME" -s "$SPACE_NAME"


