#!/bin/sh
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common-bosh.sh"
. "$BASE_DIR/common-bosh-login.sh"

# Needed for the Bosh Lite manifest
INFO 'Loading Bosh config'
export_file_vars "$BOSH_DIRECTOR_CONFIG"
INFO 'Loading Bosh SSH config'
export_file_vars "$BOSH_SSH_CONFIG" "$ENV_PREFIX"
INFO 'Loading Bosh network configuration'
export_file_vars "$NETWORK_CONFIG_FILE" "$ENV_PREFIX"

# The file is recorded relative to the base directory, but Bosh changes its directory internally, whilst running, to the location of the manifest,
# so we need to make sure the SSH file is an absolute location
eval bosh_ssh_key_file="\$${ENV_PREFIX}bosh_ssh_key_file"
findpath "${ENV_PREFIX}bosh_ssh_key_file" "$bosh_ssh_key_file"

INFO 'Deleting Bosh Deployment'
"$BOSH_CLI" delete-deployment --force $BOSH_INTERACTIVE_OPT $BOSH_TTY_OPT

INFO 'Deleting Bosh bootstrap environment'
bosh_lite delete-env "$BOSH_LITE_MANIFEST_FILE" --vars-file="$SSL_YML_RELATIVE" --vars-file="$BOSH_LITE_STATIC_IPS_YML" || FATAL 'Bosh environment deletion failed'

# It 'should' exist
if [ -f "$BOSH_LITE_STATE_FILE" ]; then
	INFO "Removing Bosh state file: $BOSH_LITE_STATE_FILE"
	rm -f "$BOSH_LITE_STATE_FILE"
fi

INFO 'Successfully deleted Bosh environment'
