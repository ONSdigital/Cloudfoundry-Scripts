#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

DEPLOYMENT_NAME="$1"
SSH_HOST="$2"
GATEWAY_USER="${3:-vcap}"
GATEWAY_HOST="$4"

DEPLOYMENT_FOLDER="$DEPLOYMENT_DIRECTORY/$DEPLOYMENT_NAME"

[ -z "$SSH_HOST" ] && FATAL 'No host to ssh onto'

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_FOLDER" ] || FATAL "Deployment does not exist '$DEPLOYMENT_FOLDER'"
[ -f "$DEPLOYMENT_FOLDER/bosh-ssh.sh" ] || FATAL "Bosh SSH config does not exist: $DEPLOYMENT_FOLDER/bosh-ssh.sh"
[ -f "$DEPLOYMENT_FOLDER/bosh-config.sh" ] || FATAL "Bosh config does not exist: $DEPLOYMENT_FOLDER/bosh-config.sh"
[ -f "$DEPLOYMENT_FOLDER/outputs.sh" ] || FATAL "AWS config does not exist: $DEPLOYMENT_FOLDER/output.sh"

eval export `prefix_vars "$DEPLOYMENT_FOLDER/bosh-ssh.sh"`
eval export `prefix_vars "$DEPLOYMENT_FOLDER/bosh-config.sh"`
eval `grep "^director_dns" "$DEPLOYMENT_FOLDER/outputs.sh" | prefix_vars`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
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

export BOSH_CA_CERT

[ -z "${GATEWAY_HOST:-$director_dns}" ] && FATAL 'No gateway host available'

INFO "Pointing Bosh at deployed Bosh: $director_dns"
"$BOSH" alias-env -e "$director_dns" "$BOSH_ENVIRONMENT"

INFO 'Attempting to login'
"$BOSH" log-in

"$BOSH" ssh --gw-private-key="$bosh_ssh_key_file" --gw-user="$GATEWAY_USER" --gw-host "${GATEWAY_HOST:-$director_dns}" "$SSH_HOST"
