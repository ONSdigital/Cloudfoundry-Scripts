#!/bin/sh
#
# See common-aws.sh for inputs
#

set -e

BASE_DIR="`dirname \"$0\"`"

# Run common AWS Cloudformation parts
. "$BASE_DIR/common-aws.sh"

aws_change_set(){
	local stack_name="$1"
	local stack_url="$2"
	local stack_outputs="$3"
	local stack_parameters="$4"

	[ -z "$stack_name" ] && FATAL 'No stack name provided'
	[ -z "$stack_url" ] && FATAL 'No stack url provided'
	[ -z "$stack_outputs" ] && FATAL 'No stack output filename provided'

	# Urgh!
	[ -n "$stack_parameters" ] && local aws_opts="--parameters '$stack_parameters'"

	shift 3

	local change_set_name="$stack_name-changeset-`date +%s`"

	check_cloudformation_stack "$stack_name"

	local stack_arn="`\"$AWS\" --output text --query \"StackSummaries[?StackName == '$stack_name'].StackId\" cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE`"

	[ -z "$stack_arn" ] && FATAL "Stack no longer exists"

	echo "$stack_url" | grep -Eq '^file://' && TEMPLATE_OPT='--template-body' || TEMPLATE_OPT='--template-url'

	INFO "Validating Cloudformation template: $stack_name"
	"$AWS" --output table cloudformation validate-template $TEMPLATE_OPT "$stack_url"

	INFO 'Creating Cloudformation stack change set'
	INFO 'Stack details:'
	sh -c "'$AWS' --output table cloudformation create-change-set --stack-name '$stack_arn' --change-set-name '$change_set_name' \
		--capabilities CAPABILITY_IAM \
		--capabilities CAPABILITY_NAMED_IAM \
		$TEMPLATE_OPT '$stack_url' \
		$aws_opts"


	INFO 'Waiting for Cloudformation changeset to be created'
	if "$AWS" --output table cloudformation wait change-set-create-complete --stack-name "$stack_arn" --change-set-name "$change_set_name"; then
		INFO 'Stack change set details:'
		"$AWS" --output table cloudformation list-change-sets --stack-name "$stack_arn"
		INFO 'Starting Cloudformation changeset'
		"$AWS" --output table cloudformation execute-change-set --stack-name "$stack_arn" --change-set-name "$change_set_name"

		INFO 'Waiting for Cloudformation stack to finish creation'
		"$AWS" --output table cloudformation wait stack-update-complete --stack-name "$stack_arn" || FATAL 'Cloudformation stack changeset failed to complete'

		parse_aws_cloudformation_outputs "$stack_arn" >"$stack_outputs"
	else
		WARN 'Change set did not contain any changes'

		WARN 'Deleting empty change set'
		"$AWS" --output table cloudformation delete-change-set --stack-name "$stack_arn" --change-set-name "$change_set_name"
	fi
}

[ -d "$DEPLOYMENT_FOLDER" ] || FATAL "Existing stack does not exist: '$DEPLOYMENT_FOLDER'"

aws_change_set "$DEPLOYMENT_NAME-preamble" "$STACK_PREAMBLE_URL" "$STACK_PREAMBLE_OUTPUTS"

eval `prefix_vars "$STACK_PREAMBLE_OUTPUTS"`

# Now we can set the main stack URL
STACK_MAIN_URL="$templates_bucket_http_url/$STACK_MAIN_FILENAME"

"$AWS" s3 sync --exclude .git --exclude LICENSE --exclude "$STACK_PREAMBLE_FILENAME" "$CLOUDFORMATION_DIR/" "s3://$templates_bucket_name"

aws_change_set "$DEPLOYMENT_NAME" "$STACK_MAIN_URL" "$STACK_MAIN_OUTPUTS" "file://$STACK_PARAMETERS"

calculate_vpc_dns_ip "$STACK_MAIN_OUTPUTS" >>"$STACK_MAIN_OUTPUTS"
