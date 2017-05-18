#!/bin/sh
#
# See common-aws.sh for inputs
# 

set -e

BASE_DIR="`dirname \"$0\"`"

# Don't complain about missing stack config file
IGNORE_MISSING_CONFIG='true'

# Run common AWS Cloudformation parts
. "$BASE_DIR/common-aws.sh"

if [ -f "$DEPLOYMENT_FOLDER/bosh-ssh.sh" ]; then
	SSH_KEY_EXISTS=1

	eval export `prefix_vars "$DEPLOYMENT_FOLDER/bosh-ssh.sh"`
fi

if [ -f "$DEPLOYMENT_FOLDER/outputs-preamble.sh" ]; then
	STACKS="$DEPLOYMENT_NAME $DEPLOYMENT_NAME-preamble"

	eval `prefix_vars "$DEPLOYMENT_FOLDER/outputs-preamble.sh"`

	INFO 'Emptying template bucket'
	"$AWS" s3 rm --recursive "s3://$templates_bucket_name"
else
	STACKS="$DEPLOYMENT_NAME"
fi

eval `prefix_vars "$DEPLOYMENT_FOLDER/bosh-ssh.sh"`

check_cloudformation_stack "$DEPLOYMENT_NAME"

# Provide the ability to optionally delete existing AWS SSH key
if [ -z "$KEEP_SSH_KEY" -o x"$KEEP_SSH_KEY" = x"false" ] && [ -n "$SSH_KEY_EXISTS" -a -n "$bosh_ssh_key_name" ] && \
	"$AWS" ec2 describe-key-pairs --key-names "$bosh_ssh_key_name" >/dev/null 2>&1; then

	INFO "Deleting SSH key: '$bosh_ssh_key_name"
	"$AWS" ec2 delete-key-pair --key-name "$bosh_ssh_key_name"
fi

for s in $STACKS; do
	INFO "Deleting stack: $s"
	"$AWS" --output table cloudformation delete-stack --stack-name "$s"

	INFO 'Waiting for Cloudformation stack to be deleted'
	"$AWS" --output table cloudformation wait stack-delete-complete --stack-name "$s"
done
