#!/bin/sh
#
# Run the Bosh CLI with the correct variables set, to minimise the number of parameters
# that need to be passed
#
# Variables:
#	DEPLOYMENT_NAME=[Deployment Name]
#
# Parameters:
#	[Deployment Name]
#	Remaning parameters are passed directly to the Bosh CLI
#
# Requires:
#	common.sh
#	common-bosh-login.sh
#

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/common-bosh-login.sh"

shift

[ -z "${GATEWAY_HOST:-$BOSH_ENVIRONMENT}" ] && FATAL 'No gateway host available'

"$BOSH_CLI" $@
