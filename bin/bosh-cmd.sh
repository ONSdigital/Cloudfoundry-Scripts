#!/bin/sh
#
# Run the Bosh CLI with the correct variables set, to minimise the number of parameters
# that need to be passed

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="$1"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/common-bosh-login.sh"

shift

[ -z "${GATEWAY_HOST:-$BOSH_ENVIRONMENT}" ] && FATAL 'No gateway host available'

"$BOSH_CLI" $@
