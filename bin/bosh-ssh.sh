#!/bin/sh
#
# Call 'bosh ssh' with the correct options to bounce onto the given host
#

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
SSH_HOST="${2:-$SSH_HOST}"
GATEWAY_USER="${3:-$GATEWAY_USER}"
GATEWAY_HOST="${4:-$GATEWAY_HOST}"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/common-bosh-login.sh"

[ -z "$SSH_HOST" ] && FATAL 'No host to ssh onto'

[ -f "$BOSH_SSH_CONFIG" ] || FATAL "Bosh SSH config does not exist: $BOSH_SSH_CONFIG"

. "$BOSH_SSH_CONFIG"

GATEWAY="${GATEWAY_HOST:-$BOSH_ENVIRONMENT}"
[ -z "$GATEWAY_USER" ] && GATEWAY_USER='vcap'

[ -z "$GATEWAY" ] && FATAL 'No gateway host available'

# Store existing path, in case the full path contains spaces
bosh_ssh_key_file_org="$bosh_ssh_key_file"
findpath bosh_ssh_key_file "$bosh_ssh_key_file"

if stat -c "%a" "$bosh_ssh_key_file" | grep -Evq '^0?600$'; then
	WARN "Fixing permissions SSH key file: $bosh_ssh_key_file"
	chmod 0600 "$bosh_ssh_key_file"
fi

# Bosh SSH doesn't handle spaces in the key filename/path
if echo "$bosh_ssh_key_file" | grep -q " "; then
	WARN "Bosh SSH does not handle spaces in the key filename/path: '$bosh_ssh_key_file'"
	WARN "Using relative path: $bosh_ssh_key_file_org"

	bosh_ssh_key_file="$bosh_ssh_key_file_org"
fi

"$BOSH_CLI" ssh --gw-private-key="$bosh_ssh_key_file" --gw-user="$GATEWAY_USER" --gw-host "$GATEWAY" "$SSH_HOST"
