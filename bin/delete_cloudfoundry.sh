#!/bin/sh
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common-bosh.sh"
. "$BASE_DIR/common-bosh-login.sh"

# Needed for the Bosh Lite manifest
INFO 'Loading Bosh config'
export_file_vars "$BOSH_DIRECTOR_CONFIG"

INFO 'Deleting Bosh Deployment'
"$BOSH_CLI" delete-deployment --force --tty

INFO 'Deleting Bosh bootstrap environment'
"$BOSH_CLI" delete-env --tty "$BOSH_LITE_INTERPOLATED_MANIFEST" || FATAL 'Bosh environment deletion failed'

# It 'should' exist
if [ -f "$BOSH_LITE_STATE_FILE" ]; then
	INFO "Removing Bosh state file: $BOSH_LITE_STATE_FILE"
	rm -f "$BOSH_LITE_STATE_FILE"
fi

INFO 'Successfully deleted Bosh environment'
