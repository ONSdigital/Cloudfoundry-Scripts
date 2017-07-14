#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

DEPLOYMENT_NAME="$1"

DEPLOYMENT_DIR="$DEPLOYMENT_BASE_DIR/$DEPLOYMENT_NAME"
STACK_OUTPUTS_DIR_RELATIVE="$DEPLOYMENT_BASE_DIR_RELATIVE/$DEPLOYMENT_NAME/outputs"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist '$DEPLOYMENT_DIR'"
[ -f "$DEPLOYMENT_DIR/bosh-ssh.sh" ] || FATAL "Bosh SSH config does not exist: $DEPLOYMENT_DIR/bosh-ssh.sh"
[ -f "$DEPLOYMENT_DIR/bosh-config.sh" ] || FATAL "Bosh config does not exist: $DEPLOYMENT_DIR/bosh-config.sh"

shift

load_output_vars "$STACK_OUTPUTS_DIR_RELATIVE" NONE director_dns
eval export `prefix_vars "$DEPLOYMENT_DIR/bosh-config.sh"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"

export BOSH_CA_CERT

[ -z "${GATEWAY_HOST:-$director_dns}" ] && FATAL 'No gateway host available'

INFO "Pointing Bosh at deployed Bosh: $director_dns"
"$BOSH" alias-env -e "$director_dns" "$BOSH_ENVIRONMENT"

INFO 'Attempting to login'
"$BOSH" log-in

"$BOSH" $@
