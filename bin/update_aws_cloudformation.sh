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
	local template_option="${5:---template-body}"
	local update_validate="${6:-update}"

	[ -z "$stack_name" ] && FATAL 'No stack name provided'
	[ -z "$stack_url" ] && FATAL 'No stack url provided'
	[ -z "$stack_outputs" ] && FATAL 'No stack output filename provided'

	# Urgh!
	[ -n "$stack_parameters" ] && local aws_opts="--parameters '$stack_parameters'"

	shift 3

	local change_set_name="$stack_name-changeset-`date +%s`"

	check_cloudformation_stack "$stack_name"

	local stack_arn="`\"$AWS\" --profile \"$AWS_PROFILE\" --output text --query \"StackSummaries[?StackName == '$stack_name'].StackId\" cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE`"

	if [ -z "$stack_arn" ]; then
		[ x"$SKIP_MISSING" = x"true" ] && log_level='WARN' || log_level='FATAL'

		$log_level "Stack no longer exists"

		return 0
	fi

	INFO "Validating Cloudformation template: $stack_url"
	"$AWS" --profile "$AWS_PROFILE" --output table cloudformation validate-template $template_option "$stack_url"

	[ x"$update_validate" = x"validate" ] && return $?

	INFO "Creating Cloudformation stack change set: $stack_name"
	INFO 'Stack details:'
	sh -c "'$AWS' --profile "$AWS_PROFILE" \
		--output table \
		cloudformation create-change-set \
		--stack-name '$stack_arn' \
		--change-set-name '$change_set_name' \
		--capabilities CAPABILITY_IAM \
		--capabilities CAPABILITY_NAMED_IAM \
		$template_option '$stack_url' \
		$aws_opts"


	INFO "Waiting for Cloudformation changeset to be created: $change_set_name"
	if "$AWS" --profile "$AWS_PROFILE" --output table cloudformation wait change-set-create-complete --stack-name "$stack_arn" --change-set-name "$change_set_name"; then
		INFO 'Stack change set details:'
		"$AWS" --profile "$AWS_PROFILE" --output table cloudformation list-change-sets --stack-name "$stack_arn"
		INFO "Starting Cloudformation changeset: $change_set_name"
		"$AWS" --profile "$AWS_PROFILE" --output table cloudformation execute-change-set --stack-name "$stack_arn" --change-set-name "$change_set_name"

		INFO 'Waiting for Cloudformation stack to finish creation'
		"$AWS" --profile "$AWS_PROFILE" --output table cloudformation wait stack-update-complete --stack-name "$stack_arn" || FATAL 'Cloudformation stack changeset failed to complete'

		parse_aws_cloudformation_outputs "$stack_arn" >"$stack_outputs"
	else
		WARN "Change set did not contain any changes: $change_set_name"

		WARN "Deleting empty change set: $change_set_name"
		"$AWS" --profile "$AWS_PROFILE" --output table cloudformation delete-change-set --stack-name "$stack_arn" --change-set-name "$change_set_name"
	fi
}

if [ -f "$STACK_PREAMBLE_OUTPUTS" ] && [ -z "$SKIP_STACK_PREAMBLE_OUTPUTS_CHECK" -o x"$SKIP_STACK_PREAMBLE_OUTPUTS_CHECK" = x"false" ]; then
	[ -f "$STACK_PREAMBLE_OUTPUTS" ] || FATAL "Existing stack preamble outputs do exist: '$STACK_PREAMBLE_OUTPUTS'"
fi

if [ -f "$STACK_MAIN_OUTPUTS" ] && [ -z "$SKIP_STACK_MAIN_OUTPUTS_CHECK" -o x"$SKIP_STACK_MAIN_OUTPUTS_CHECK" = x"false" ]; then
	[ -f "$STACK_MAIN_OUTPUTS" ] || FATAL "Existing stack main outputs do exist: '$STACK_MAIN_OUTPUTS'"
fi

# We use older options in find due to possible lack of -printf and/or -regex options
STACK_FILES="`find "$CLOUDFORMATION_DIR" -mindepth 1 -maxdepth 1 -name "$AWS_CONFIG_PREFIX-*.json" | awk -F/ '!/preamble/{print $NF}' | sort`"

pushd "$CLOUDFORMATION_DIR" >/dev/null
validate_json_files "$STACK_PREAMBLE_FILENAME" $STACK_FILES
popd >/dev/null

aws_change_set "$DEPLOYMENT_NAME-preamble" "$STACK_PREAMBLE_URL" "$STACK_PREAMBLE_OUTPUTS"

INFO 'Parsing preamble outputs'
eval `prefix_vars "$STACK_PREAMBLE_OUTPUTS"`

INFO 'Copying templates to S3'
"$AWS" --profile "$AWS_PROFILE" s3 sync "$CLOUDFORMATION_DIR/" "s3://$templates_bucket_name" --exclude '*' --include "$AWS_CONFIG_PREFIX-*.json" --include 'Templates/*.json'

# Now we can set the main stack URL
STACK_MAIN_URL="$templates_bucket_http_url/$STACK_MAIN_FILENAME"

for _action in validate update; do
	for _file in $STACK_FILES; do
		STACK_NAME="$DEPLOYMENT_NAME-`echo $_file| sed $SED_EXTENDED -e "s/^$AWS_CONFIG_PREFIX-//g" -e 's/\.json$//g'`"
		STACK_PARAMETERS="$STACK_PARAMETERS_DIR/parameters-$STACK_NAME.$STACK_PARAMETERS_SUFFIX"
		STACK_URL="$templates_bucket_http_url/$_file"
		STACK_OUTPUTS="$STACK_OUTPUTS_DIR/outputs-$STACK_NAME.$STACK_OUTPUTS_SUFFIX"

		[ "$_action" = x"update" ] && update_parameters_file "$CLOUDFORMATION_DIR/$_file" "$STACK_PARAMETERS"

		aws_change_set "$STACK_NAME" "$STACK_URL" "$STACK_OUTPUTS" "file://$STACK_PARAMETERS" --template-url $_action || FATAL "Failed to $_action stack: $STACK_NAME, $_file"
	done
done
