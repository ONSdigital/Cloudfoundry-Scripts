#!/bin/sh
#
# See common-aws.sh for inputs
#

set -e

BASE_DIR="`dirname \"$0\"`"

# Run common AWS Cloudformation parts
. "$BASE_DIR/common-aws.sh"

if [ -d "$STACK_OUTPUTS_DIR" ] && [ -z "$SKIP_STACK_OUTPUTS_DIR" -o x"$SKIP_STACK_OUTPUTS_DIR" = "false" ] && [ x"$SKIP_EXISTING" != x"true" ]; then
	 FATAL "Existing stack outputs directory: '$STACK_OUTPUTS_DIR', do you need to run\n\t$BASE_DIR/update_aws_cloudformation.sh instead?"
fi

PREAMBLE_STACK="$DEPLOYMENT_NAME-preamble"
BOSH_SSH_KEY_NAME="$DEPLOYMENT_NAME-key"

# We don't want to store the full path when we add the ssh-key location, so we use a relative one - but we use the absolute one for our checks
BOSH_SSH_KEY_FILENAME="$DEPLOYMENT_DIR/ssh-key"
BOSH_SSH_KEY_FILENAME_RELATIVE="$DEPLOYMENT_DIR_RELATIVE/ssh-key"

# We use older options in find due to possible lack of -printf and/or -regex options
STACK_FILES="`find "$CLOUDFORMATION_DIR" -mindepth 1 -maxdepth 1 -name "$AWS_CONFIG_PREFIX-*.json" | awk -F/ '!/preamble/{print $NF}' | sort`"
STACK_TEMPLATES_FILES="`find "$CLOUDFORMATION_DIR/Templates" -mindepth 1 -maxdepth 1 -name "*.json" | awk -F/ '{printf("%s/%s\n",$(NF-1),$NF)}' | sort`"

cd "$CLOUDFORMATION_DIR"
validate_json_files "$STACK_PREAMBLE_FILENAME" $STACK_FILES $STACK_TEMPLATES_FILES
cd - >/dev/null

if [ ! -d "$STACK_OUTPUTS_DIR" ]; then
	INFO "Creating directory to hold stack outputs"
	mkdir -p "$STACK_OUTPUTS_DIR"
fi

if [ ! -d "$STACK_PARAMETERS_DIR" ]; then
	INFO "Creating directory to hold stack parameters"
	mkdir -p "$STACK_PARAMETERS_DIR"
fi

if [ -z "$SKIP_EXISTING" -o x"$SKIP_EXISTING" != x"true" ] || ! stack_exists "$PREAMBLE_STACK"; then
	INFO 'Checking for existing Cloudformation stack'
	"$AWS" --profile "$AWS_PROFILE" --query "StackSummaries[?starts_with(StackName,'$DEPLOYMENT_NAME-') &&  StackStatus != 'DELETE_COMPLETE'].StackName" \
		cloudformation list-stacks | grep -q "^$DEPLOYMENT_NAME" && FATAL 'Stack(s) exists'

	INFO 'Validating Cloudformation Preamble Template'
	"$AWS" --profile "$AWS_PROFILE" --output table cloudformation validate-template --template-body "$STACK_PREAMBLE_URL"

	# The preamble must be kept smaller than 51200 as we use it to host templates
	INFO 'Creating Cloudformation stack preamble'
	INFO 'Stack details:'
	"$AWS" --profile "$AWS_PROFILE" \
		--output table \
		cloudformation create-stack \
		--capabilities CAPABILITY_IAM \
		--capabilities CAPABILITY_NAMED_IAM \
		--stack-name "$DEPLOYMENT_NAME-preamble" \
		--capabilities CAPABILITY_IAM \
		--capabilities CAPABILITY_NAMED_IAM \
		--template-body "$STACK_PREAMBLE_URL"

	INFO 'Waiting for Cloudformation stack to finish creation'
	"$AWS" --profile "$AWS_PROFILE" cloudformation wait stack-create-complete --stack-name "$DEPLOYMENT_NAME-preamble" || FATAL 'Failed to create Cloudformation preamble stack'

	GENERATE_PREAMBLE_OUTPUT=true
fi

if [ ! -f "$STACK_PREAMBLE_OUTPUTS" -o x"$GENERATE_PREAMBLE_OUTPUTS" = x"true" ]; then
	parse_aws_cloudformation_outputs "$DEPLOYMENT_NAME-preamble" >"$STACK_PREAMBLE_OUTPUTS"
fi

[ -f "$STACK_PREAMBLE_OUTPUTS" ] || FATAL "No preamble outputs available: $STACK_PREAMBLE_OUTPUTS"

eval `prefix_vars "$STACK_PREAMBLE_OUTPUTS"`

INFO 'Copying templates to S3'
"$AWS" --profile "$AWS_PROFILE" s3 sync "$CLOUDFORMATION_DIR/" "s3://$templates_bucket_name" --exclude '*' --include "$AWS_CONFIG_PREFIX-*.json" --include 'Templates/*.json'

for stack_file in $STACK_FILES; do
	STACK_NAME="`stack_file_name "$DEPLOYMENT_NAME" "$stack_file"`"
	STACK_URL="$templates_bucket_http_url/$stack_file"

	INFO "Validating Cloudformation template: '$stack_file'"
	"$AWS" --profile "$AWS_PROFILE" --output table cloudformation validate-template --template-url "$STACK_URL" || FAILED=$?

	if [ 0$FAILED -ne 0 ] && [ -z "$SKIP_EXISTING" -o x"$SKIP_EXISTING" != x"true" ]; then
		INFO 'Cleaning preamble S3 bucket'
		"$AWS" --profile "$AWS_PROFILE" s3 rm --recursive "s3://$templates_bucket_name"

		INFO "Deleting stack: '$PREAMBLE_STACK'"
		"$AWS" --profile "$AWS_PROFILE" --output table cloudformation delete-stack --stack-name "$PREAMBLE_STACK"

		INFO "Waiting for Cloudformation stack deletion to finish creation: '$PREAMBLE_STACK'"
		"$AWS" --profile "$AWS_PROFILE" cloudformation wait stack-delete-complete --stack-name "$PREAMBLE_STACK" || FATAL 'Failed to delete Cloudformation stack'

		[ -d "$STACK_OUTPUTS_DIR" ] && rm -rf "$STACK_OUTPUTS_DIR"

		FATAL "Problem validating template: '$stack_file'"
	elif [ 0$FAILED -ne 0 ]; then
		FATAL "Failed to validate stack: $STACK_NAME, $stack_file"
	fi
done

for stack_file in $STACK_FILES; do
	STACK_NAME="`stack_file_name "$DEPLOYMENT_NAME" "$stack_file"`"
	STACK_URL="$templates_bucket_http_url/$stack_file"
	STACK_PARAMETERS="$STACK_PARAMETERS_DIR/parameters-$STACK_NAME.$STACK_PARAMETERS_SUFFIX"
	STACK_OUTPUTS="$STACK_OUTPUTS_DIR/outputs-$STACK_NAME.$STACK_OUTPUTS_SUFFIX"

	if [ -n "$SKIP_EXISTING" -a x"$SKIP_EXISTING" = x"true" ] && stack_exists "$STACK_NAME"; then
		WARN "Stack already exists, skipping: $STACK_NAME"

		# We don't continue immediately in case we are missing the parameters file, eg if we
		# were run before but the parameters/outputs/etc were never saved
		STACK_EXISTS=true
	fi

	[ -f "$AWS_PASSWORD_CONFIG_FILE" ] || echo '# AWS Passwords' >"$AWS_PASSWORD_CONFIG_FILE"
	for i in `find_aws_parameters "$CLOUDFORMATION_DIR/$stack_file" '^[A-Za-z]+Password$' | capitalise_aws`; do
		# eg rds_cf_instance_password
		lower_varname="`echo $i | tr '[[:upper:]]' '[[:lower:]]'`"

		if grep -Eq "^$lower_varname=" "$AWS_PASSWORD_CONFIG_FILE"; then
			eval `grep -Eq "^$lower_varname=" "$AWS_PASSWORD_CONFIG_FILE"`

			eval "$i='$lower_varname'"

			continue
		fi

		# eg RDS_CF_INSTANCE_PASSWORD
		password="`generate_password 32`"

		eval "$i='$password'"

		echo "$lower_varname='$password'"
	done >>"$AWS_PASSWORD_CONFIG_FILE"

	if [ x"$STACK_EXISTS" != x"true" -o ! -f "$STACK_PARAMETERS" ]; then
		INFO "Generating Cloudformation parameters JSON file for '$STACK_NAME': $STACK_PARAMETERS"
		generate_parameters_file "$CLOUDFORMATION_DIR/$stack_file" >"$STACK_PARAMETERS"
	fi

	if [ x"$STACK_EXISTS" != x"true" ]; then
		INFO "Creating Cloudformation stack: '$STACK_NAME'"
		INFO 'Stack details:'
			"$AWS" --profile "$AWS_PROFILE"\
			--output table \
			cloudformation create-stack \
			--stack-name "$STACK_NAME" \
			--template-url "$STACK_URL" \
			--capabilities CAPABILITY_IAM \
			--capabilities CAPABILITY_NAMED_IAM \
			--on-failure DO_NOTHING \
			--parameters "file://$STACK_PARAMETERS"

		INFO "Waiting for Cloudformation stack to finish creation: '$STACK_NAME'"
		"$AWS" --profile "$AWS_PROFILE" cloudformation wait stack-create-complete --stack-name "$STACK_NAME" || FATAL 'Failed to create Cloudformation stack'
	fi

	if [ ! -f "$STACK_OUTPUTS" ]; then
		parse_aws_cloudformation_outputs "$STACK_NAME" >"$STACK_OUTPUTS"
	fi

	unset STACK_EXISTS
done

INFO 'Configuring DNS settings'
load_output_vars "$STACK_OUTPUTS_DIR" NONE vpc_cidr
calculate_dns "$vpc_cidr" >"$STACK_OUTPUTS_DIR/outputs-dns.$STACK_OUTPUTS_SUFFIX"

# XXX
# For bonus points we should really check the local SSH key fingerprint matches the AWS SSH key finger print
#
# Provide the ability to optionally delete existing AWS SSH key
"$AWS" --profile "$AWS_PROFILE" ec2 describe-key-pairs --key-names "$BOSH_SSH_KEY_NAME" >/dev/null 2>&1 && AWS_KEY_EXISTS='true'

if [ x"$DELETE_AWS_SSH_KEY" = x"true" ]; then
	"$AWS" --profile "$AWS_PROFILE" ec2 delete-key-pair --key-name "$BOSH_SSH_KEY_NAME"

	AWS_KEY_EXISTS='false'
fi

if [ x"$REGENERATE_SSH_KEY" = x"true" ]; then
	rm -f "$BOSH_SSH_KEY_FILENAME" "$BOSH_SSH_KEY_FILENAME.pub"

	[ x"$AWS_KEY_EXISTS" = x"true" ] && "$AWS" --profile "$AWS_PROFILE" ec2 delete-key-pair --key-name "$BOSH_SSH_KEY_NAME"
fi

# We don't have a local key, so we have to generate one
if [ ! -f "$BOSH_SSH_KEY_FILENAME" ]; then
	INFO 'Generating SSH key'
	[ -n "$SECURE_SSH_KEY" ] && ssh-keygen -f "$BOSH_SSH_KEY_FILENAME" || ssh-keygen -f "$BOSH_SSH_KEY_FILENAME" -P ''
fi

[ -f "$BOSH_SSH_KEY_FILENAME" ] || FATAL "SSH key does not exist '$BOSH_SSH_KEY_FILENAME'"

if [ x"$AWS_KEY_EXISTS" != x"true" ]; then
	INFO "Uploading $BOSH_SSH_KEY_NAME to AWS"
	KEY_DATA="`cat \"$BOSH_SSH_KEY_FILENAME.pub\"`"
	"$AWS" --profile "$AWS_PROFILE" ec2 import-key-pair --key-name "$BOSH_SSH_KEY_NAME" --public-key-material "$KEY_DATA"
fi

INFO 'Creating additional environment configuration'
cat >"$BOSH_SSH_CONFIG" <<EOF
# Bosh SSH vars
bosh_ssh_key_name='$BOSH_SSH_KEY_NAME'
bosh_ssh_key_file='$BOSH_SSH_KEY_FILENAME_RELATIVE'
EOF
