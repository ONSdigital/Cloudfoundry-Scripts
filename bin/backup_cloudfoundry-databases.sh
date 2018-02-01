#!/bin/sh
#
# Run Bosh errands that are prefxed with 'backup-'
#
# Variables:
#	DEPLOYMENT_NAME=[Deployment name]
#
# Parameters:
#	[Deployment name]
#
# Requires:
#	common.sh
# 	common-bosh-login.sh

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/common-bosh-login.sh"

for _e in `"$BOSH_CLI" errands | grep -E '^backup-'`; do
	"$BOSH_CLI" run-errand "$_e"
done
