#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

DEPLOYMENT_NAME="$1"

DEPLOYMENT_FOLDER="$DEPLOYMENT_DIRECTORY/$DEPLOYMENT_NAME"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_FOLDER" ] || FATAL "Deployment does not exist '$DEPLOYMENT_FOLDER'"
[ -f "$DEPLOYMENT_FOLDER/bosh-ssh.sh" ] || FATAL "Bosh SSH config does not exist: $DEPLOYMENT_FOLDER/bosh-ssh.sh"
[ -f "$DEPLOYMENT_FOLDER/bosh-config.sh" ] || FATAL "Bosh config does not exist: $DEPLOYMENT_FOLDER/bosh-config.sh"
[ -f "$DEPLOYMENT_FOLDER/outputs.sh" ] || FATAL "AWS config does not exist: $DEPLOYMENT_FOLDER/output.sh"

shift

eval export `prefix_vars "$DEPLOYMENT_FOLDER/bosh-config.sh"`
eval `grep "^director_dns" "$DEPLOYMENT_FOLDER/outputs.sh" | prefix_vars`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"

export BOSH_CA_CERT

[ -z "${GATEWAY_HOST:-$director_dns}" ] && FATAL 'No gateway host available'

INFO "Pointing Bosh at deployed Bosh: $director_dns"
"$BOSH" alias-env -e "$director_dns" "$BOSH_ENVIRONMENT"

INFO 'Attempting to login'
"$BOSH" log-in

"$BOSH" $@
