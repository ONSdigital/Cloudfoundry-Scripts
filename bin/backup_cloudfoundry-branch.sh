#!/bin/sh
#
# Backup/restore a deployment branch to/from the given S3 bucket
#
# Variables:
#	DEPLOYMENT_NAME=[Deployment name]
#	S3_BUCKET_LOCATION=[S3 Bucket location]
#
# Parameters:
#	[Deployment name]
#	[restore|backup]
#	[S3 Bucket location]
#
# Requires common-aws.sh
#

set -e

BASE_DIR="`dirname \"$0\"`"

export NON_AWS_DEPLOY=true

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
ACTION="${2:-backup}"
S3_BUCKET_LOCATION="${3:-$S3_BUCKET_LOCATION}"

for i in 1 2 3; do
	[ -n "$1" ] && shift 1
done

. "$BASE_DIR/common-aws.sh"

[ -z "$S3_BUCKET_LOCATION" ] && FATAL 'No source/destination provided'

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist '$DEPLOYMENT_DIR'"

INFO 'Loading AWS outputs'
load_outputs "$STACK_OUTPUTS_DIR"

[ -n "$aws_region" ] && export AWS_DEFAULT_REGION="$aws_region"

# The shared bucket name is either the source or the destination
if [ x"$ACTION" = x"backup" ]; then
	log_name='Backup'
	src='./'
	dst="$S3_BUCKET_LOCATION"

elif [ x"$ACTION" = x"restore" ]; then
	log_name='Restore'
	src="$S3_BUCKET_LOCATION"
	dst='./'

	git checkout -b "$DEPLOYMENT_NAME"
else

	FATAL "Unknown action: $ACTION"
fi


"$AWS_CLI" s3 sync --acl bucket-owner-full-control --delete "$src" "$dst" || FATAL "$log_name failed"

INFO "$log_name successful"
