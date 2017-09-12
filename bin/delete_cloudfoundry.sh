#!/bin/sh
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common-bosh.sh"
	
# Sanity check
[ -f "$PASSWORD_CONFIG_FILE" ] || FATAL "Password configuration file does not exist: '$PASSWORD_CONFIG_FILE'"

INFO 'Loading password configuration'
eval export `prefix_vars "$PASSWORD_CONFIG_FILE" "$ENV_PREFIX"`
# We set BOSH_CLIENT_SECRET to this later on
eval DIRECTOR_PASSWORD="\$${ENV_PREFIX}director_password"


INFO 'Loading Bosh config'
[ -f "$BOSH_DIRECTOR_CONFIG" ] || FATAL "Bosh configuration file does not exist: '$BOSH_DIRECTOR_CONFIG'"
eval export `prefix_vars "$BOSH_DIRECTOR_CONFIG"`
eval export `prefix_vars "$BOSH_SSH_CONFIG" "$ENV_PREFIX"`
INFO 'Loading Bosh network configuration'
eval export `prefix_vars "$NETWORK_CONFIG_FILE" "$ENV_PREFIX"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
export BOSH_CA_CERT

# The file is recorded relative to the base directory, but Bosh changes its directory internally, whilst running, to the location of the manifest,
# so we need to make sure the SSH file is an absolute location
eval bosh_ssh_key_file="\$${ENV_PREFIX}bosh_ssh_key_file"
findpath "${ENV_PREFIX}bosh_ssh_key_file" "$bosh_ssh_key_file"

INFO 'Pointing Bosh at newly deployed Bosh'
"$BOSH" alias-env $BOSH_TTY_OPT -e "$BOSH_ENVIRONMENT" "$BOSH_ENVIRONMENT" >&2

INFO 'Attempting to login'
"$BOSH" log-in $BOSH_TTY_OPT >&2

INFO 'Deleting Bosh Deployment'
"$BOSH" delete-deployment --force $BOSH_INTERACTIVE_OPT $BOSH_TTY_OPT

INFO 'Deleting Bosh bootstrap environment'
bosh_env delete-env || FATAL 'Bosh environment deletion failed'

# It 'should' exist
if [ -f "$BOSH_LITE_STATE_FILE" ]; then
	INFO "Removing Bosh state file: $BOSH_LITE_STATE_FILE"
	rm -f "$BOSH_LITE_STATE_FILE"
fi

INFO 'Successfully deleted Bosh environment'
