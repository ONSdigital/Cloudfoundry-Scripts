#!/bin/sh
#
# See common-aws.sh for inputs
#

set -e

BASE_DIR="`dirname \"$0\"`"

# Run common AWS Cloudformation parts
. "$BASE_DIR/common-aws.sh"

[ -d "$DEPLOYMENT_FOLDER" ] && FATAL "Existing stack exists: '$DEPLOYMENT_FOLDER', do you need to run\n\t$BASE_DIR/update_aws_cloudformation.sh instead?"

BOSH_SSH_KEY_NAME="$DEPLOYMENT_NAME-key"
BOSH_SSH_FILE="$DEPLOYMENT_FOLDER/bosh-ssh.sh"

# We don't want to store the full path when we add the ssh-key location, so we use a relative one - but we use the absolute one for our checks
BOSH_SSH_KEY_FILENAME="$DEPLOYMENT_FOLDER/ssh-key"
BOSH_SSH_KEY_FILENAME_RELATIVE="$DEPLOYMENT_FOLDER_RELATIVE/ssh-key"

INFO 'Checking for existing Cloudformation stack'
"$AWS" --query "StackSummaries[?(StackName == '$DEPLOYMENT_NAME' || StackName == '$DEPLOYMENT_NAME-preamble' ) && StackStatus != 'DELETE_COMPLETE'].StackName" \
	cloudformation list-stacks | grep -q "^$DEPLOYMENT_NAME" && FATAL 'Stack exists'

INFO 'Validating Cloudformation Preamble Template'
"$AWS" --output table cloudformation validate-template --template-body "$STACK_PREAMBLE_URL"
"$AWS" --output table cloudformation validate-template --template-body "$STACK_PREAMBLE_URL"

# The pre-amble must be kept smaller than 51200 as we use it to host templates
INFO 'Creating Cloudformation stack preamble'
INFO 'Stack details:'
"$AWS" --output table cloudformation create-stack \
	--capabilities CAPABILITY_IAM \
	--capabilities CAPABILITY_NAMED_IAM \
	--stack-name "$DEPLOYMENT_NAME-preamble" \
	--capabilities CAPABILITY_IAM \
	--capabilities CAPABILITY_NAMED_IAM \
	--template-body "$STACK_PREAMBLE_URL"

INFO 'Waiting for Cloudformation stack to finish creation'
"$AWS" cloudformation wait stack-create-complete --stack-name "$DEPLOYMENT_NAME-preamble" || FATAL 'Failed to create Cloudformation preamble stack'

INFO "Creating '$DEPLOYMENT_FOLDER' to hold stack outputs"
mkdir -p "$DEPLOYMENT_FOLDER"

parse_aws_cloudformation_outputs "$DEPLOYMENT_NAME-preamble" >"$STACK_PREAMBLE_OUTPUTS"

[ -f "$STACK_PREAMBLE_OUTPUTS" ] || FATAL "No preamble outputs available: $STACK_PREAMBLE_OUTPUTS"

eval `prefix_vars "$STACK_PREAMBLE_OUTPUTS"`

INFO 'Copying templates to S3'
"$AWS" s3 sync --exclude .git --exclude LICENSE --exclude "$STACK_PREAMBLE_FILENAME" "$CLOUDFORMATION_DIR/" "s3://$templates_bucket_name"
"$AWS" s3 cp "$STACK_MAIN_FILE" "s3://$templates_bucket_name/$MAIN_TEMPLATE_STACK_NAME"

# Now we can set the main stack URL
STACK_MAIN_URL="$templates_bucket_http_url/$STACK_MAIN_FILENAME"

INFO 'Validating Cloudformation templates: main template'
"$AWS" --output table cloudformation validate-template --template-url "$STACK_MAIN_URL" || FAILED=$?

if [ 0$FAILED -ne 0 ]; then
	INFO 'Cleaning preamble S3 bucket'
	"$AWS" s3 rm --recursive "s3://$templates_bucket_name"

	INFO 'Deleting preamble stack'
	"$AWS" --output table cloudformation delete-stack --stack-name "$DEPLOYMENT_NAME-preamble"

	FATAL 'Problem validating template'
fi


INFO 'Validating Cloudformation Template'
"$AWS" --output table cloudformation validate-template --template-url "$STACK_MAIN_URL"

INFO 'Generating Cloudformation parameters JSON file'
cat >"$STACK_PARAMETERS" <<EOF
[
	{
		"ParameterKey": "DeploymentName",
		"ParameterValue": "$DEPLOYMENT_NAME"
	},
	{
		"ParameterKey": "Organisation",
		"ParameterValue": "${ORGANISATION:-Unknown}"
	},
	{
		"ParameterKey": "HostedZone",
		"ParameterValue": "${HOSTED_ZONE:-localhost}"
	},
	{
		"ParameterKey": "External1Cidr",
		"ParameterValue": "${EXTERNAL1_CIDR:-127.0.0.0/8}"
	},
	{
		"ParameterKey": "External2idr",
		"ParameterValue": "${EXTERNAL2_CIDR:-127.0.0.0/8}"
	},
	{
		"ParameterKey": "External3Cidr",
		"ParameterValue": "${EXTERNAL3_CIDR:-127.0.0.0/8}"
	},
	{
		"ParameterKey": "External4Cidr",
		"ParameterValue": "${EXTERNAL4_CIDR:-127.0.0.0/8}"
	},
	{
		"ParameterKey": "External5Cidr",
		"ParameterValue": "${EXTERNAL5_CIDR:-127.0.0.0/8}"
	},
	{
		"ParameterKey": "External6Cidr",
		"ParameterValue": "${EXTERNAL6_CIDR:-127.0.0.0/8}"
	},
	{
		"ParameterKey": "External7Cidr",
		"ParameterValue": "${EXTERNAL7_CIDR:-127.0.0.0/8}"
	},
	{
		"ParameterKey": "External8Cidr",
		"ParameterValue": "${EXTERNAL8_CIDR:-127.0.0.0/8}"
	}
]
EOF


INFO 'Creating Cloudformation stack'
INFO 'Stack details:'
"$AWS" --output table cloudformation create-stack \
	--stack-name "$DEPLOYMENT_NAME" \
	--template-url "$STACK_MAIN_URL" \
	--capabilities CAPABILITY_IAM \
	--capabilities CAPABILITY_NAMED_IAM \
	--parameters "file://$STACK_PARAMETERS"

INFO 'Waiting for Cloudformation stack to finish creation'
"$AWS" cloudformation wait stack-create-complete --stack-name "$DEPLOYMENT_NAME" || FATAL 'Failed to create Cloudformation stack'

parse_aws_cloudformation_outputs "$DEPLOYMENT_NAME" >"$STACK_MAIN_OUTPUTS"

calculate_dns_ip "$STACK_MAIN_OUTPUTS" >>"$STACK_MAIN_OUTPUTS"

# XXX
# For bonus points we should really check the local SSH key fingerprint matches the AWS SSH key finger print
#
# Provide the ability to optionally delete existing AWS SSH key
if "$AWS" ec2 describe-key-pairs --key-names "$BOSH_SSH_KEY_NAME" >/dev/null 2>&1; then
	INFO "Existing key $BOSH_SSH_KEY_NAME exists:"
	"$AWS" --output table ec2 describe-key-pairs --key-names "$BOSH_SSH_KEY_NAME"

	AWS_KEY_EXISTS=1

	# We want the ability to run silently (eg via Jenkins)
	if [ -z "$DELETE_AWS_KEY" ]; then
		read -p "Delete existing AWS SSH key (Y/N)" DELETE_AWS_KEY
	fi

	if [ -n "$DELETE_AWS_KEY" -o x"$DELETE_AWS_KEY" != x"N" ]; then
		unset AWS_KEY_EXISTS

		"$AWS" ec2 delete-key-pair --key-name "$BOSH_SSH_KEY_NAME"
	fi
fi


# ... and the ability to delete existing local versions of the SSH key
if [ -f "$BOSH_SSH_KEY_FILENAME" ]; then
	LOCAL_KEY_EXISTS=1

	if [ -z "$DELETE_LOCAL_KEY" ]; then
		read -p "Delete existing local SSH key (Y/N)" DELETE_LOCAL_KEY
	fi

	if [ -n "$DELETE_LOCAL_KEY" -o x"$DELETE_LOCAL_KEY" != x"N" ]; then
		unset LOCAL_KEY_EXISTS

		rm -f "$BOSH_SSH_KEY_FILENAME" "$BOSH_SSH_KEY_FILENAME.pub"
	fi
fi

[ -n "$AWS_KEY_EXISTS" -a -z "$LOCAL_KEY_EXISTS" ] && FATAL 'No local SSH key available'

# We don't have a local key, so we have to generate one
if [ ! -f "$BOSH_SSH_KEY_FILENAME" ]; then
	# This will need silencing
	INFO 'Generating SSH key'
	[ -n "$INSECURE_SSH_KEY" ] && ssh-keygen -f "$BOSH_SSH_KEY_FILENAME" -P '' || ssh-keygen -f "$BOSH_SSH_KEY_FILENAME"
fi

[ -f "$BOSH_SSH_KEY_FILENAME" ] || FATAL "SSH key does not exist '$BOSH_SSH_KEY_FILENAME'"

if [ -z "$AWS_KEY_EXISTS" ]; then
	INFO "Uploading $BOSH_SSH_KEY_NAME to AWS"
	KEY_DATA="`cat \"$BOSH_SSH_KEY_FILENAME.pub\"`"
	"$AWS" ec2 import-key-pair --key-name "$BOSH_SSH_KEY_NAME" --public-key-material "$KEY_DATA"
fi

INFO 'Creating additional environment configuration'
cat >"$BOSH_SSH_FILE" <<EOF
# Bosh SSH vars
bosh_ssh_key_name='$BOSH_SSH_KEY_NAME'
bosh_ssh_key_file='$BOSH_SSH_KEY_FILENAME_RELATIVE'
EOF
