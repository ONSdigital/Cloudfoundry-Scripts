#!/bin/sh
#
# Backup/restore a deployment branch to/from the given S3 bucket
#

set -e

BASE_DIR="`dirname \"$0\"`"

export NON_AWS_DEPLOY=true

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
ACTION="${2:-backup}"
SRC_OR_DST="$3"

. "$BASE_DIR/common-aws.sh"

[ -z "$SRC_OR_DST" ] && FATAL 'No source/destination provided'

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist '$DEPLOYMENT_DIR'"

load_outputs "$STACK_OUTPUTS_DIR"

[ -n "$aws_region" ] && export AWS_DEFAULT_REGION="$aws_region"

# The shared bucket name is either the source or the destination
if [ x"$ACTION" = x"backup" ]; then
	log_name='Backup'
	src='./'
	dst="s3://$s3_bucket"

elif [ x"$ACTION" = x"restore" ]; then
	log_name='Restore'
	src="s3://$s3_bucket"
	dst='./'

	git checkout "$DEPLOYMENT_NAME"
else

	FATAL "Unknown action: $ACTION"
fi


"$AWS" s3 sync --acl bucket-owner-full-control --delete "$src" "$dst" || LOG_LEVEL='FATAL'

"${LOG_LEVEL:-INFO}" "$log_name ${STATE:-Successful}"
