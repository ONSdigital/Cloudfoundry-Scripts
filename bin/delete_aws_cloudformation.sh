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

empty_bucket(){
	bucket_name="$1"

	[ -n "$1" ] || FATAL 'No bucket name provided'

	if "$AWS" --profile "$AWS_PROFILE" --output text --query "Buckets[?Name == '$bucket_name'].Name" s3api list-buckets | grep -Eq "^$bucket_name$"; then
		INFO "Emptying bucket: $bucket_name"
		"$AWS" --profile "$AWS_PROFILE" s3 rm --recursive "s3://$bucket_name"
	fi
}

load_outputs "$STACK_OUTPUTS_DIR"

if [ -n "$BOSH_SSH_CONFIG" -a -f "$BOSH_SSH_CONFIG" ]; then
	SSH_KEY_EXISTS=1

	eval export `prefix_vars "$BOSH_SSH_CONFIG"`
fi

if [ -f "$STACK_OUTPUTS_DIR/outputs-preamble.sh" ]; then
	eval `prefix_vars "$STACK_OUTPUTS_DIR/outputs-preamble.sh"`

	empty_bucket "$templates_bucket_name"
fi

if [ -n "$s3_buckets" ]; then
	OLDIFS="$IFS"
	IFS=","
	for bucket in $s3_buckets; do
		empty_bucket "$bucket"
	done
	IFS="$OLDIFS"
fi

# Provide the ability to optionally delete existing AWS SSH key
if [ -z "$KEEP_SSH_KEY" -o x"$KEEP_SSH_KEY" = x"false" ] && [ -n "$SSH_KEY_EXISTS" -a -n "$bosh_ssh_key_name" ] && \
	"$AWS" --profile "$AWS_PROFILE" ec2 describe-key-pairs --key-names "$bosh_ssh_key_name" >/dev/null 2>&1; then

	INFO "Deleting SSH key: '$bosh_ssh_key_name'"
	"$AWS" --profile "$AWS_PROFILE" ec2 delete-key-pair --key-name "$bosh_ssh_key_name"
fi

# We use older options in find due to possible lack of -printf and/or -regex options
for _file in `find "$CLOUDFORMATION_DIR" -mindepth 1 -maxdepth 1 -name "$AWS_CONFIG_PREFIX-*.json" | awk -F/ '!/preamble/{print $NF}' | sort` AWS-Bosh-preamble.json; do
	STACK_NAME="`stack_file_name "$DEPLOYMENT_NAME" "$_file"`"

	check_cloudformation_stack "$STACK_NAME" || continue

	INFO "Deleting stack: $s"
	"$AWS" --profile "$AWS_PROFILE" --output table cloudformation delete-stack --stack-name "$STACK_NAME"

	INFO 'Waiting for Cloudformation stack to be deleted'
	"$AWS" --profile "$AWS_PROFILE" --output table cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
done
