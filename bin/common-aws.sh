

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
[ -n "$1" ] && shift

# Allow script to be used by non-AWS Cloudformation deployment steps
if [ -z "$NON_AWS_DEPLOY" ]; then
	AWS_CONFIG_PREFIX="${1:-AWS-Bosh}"
	[ -n "$1" ] && shift

	HOSTED_ZONE="${HOSTED_ZONE:-$1}"
	[ -n "$1" ] && shift
fi


# Set AWS specific variables (http://docs.aws.amazon.com/cli/latest/userguide/cli-environment.html)
export AWS_DEFAULT_REGION="${1:-${AWS_DEFAULT_REGION:-$AWS_REGION}}"
export AWS_ACCESS_KEY_ID="${2:-$AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${3:-$AWS_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_OUTPUT="${AWS_DEFAULT_OUTPUT:-table}"

[ -n "$AWS_PROFILE" ] && export AWS_PROFILE

. "$BASE_DIR/common.sh"

find_aws

[ x"$AWS_DEBUG" = x"true" ] && AWS_DEBUG_OPTION='--debug'

if [ -z "$AWS_DEFAULT_REGION" ]; then
	[ -f ~/.aws/config ] && CONFIGURED_AWS_REGION="`"$AWS_CLI" configure get region`"

	# Provide a default - these should come from a configuration/defaults file
	DEFAULT_AWS_REGION="${DEFAULT_AWS_REGION:-${CONFIGURED_AWS_REGION:-eu-central-1}}"
fi

# Do we need to update credentials?
if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" ]; then
	[ -f ~/.aws/credentials ] || FATAL 'No AWS_ACCESS_KEY_ID and/or AWS_SECRET_ACCESS_KEY provided and no AWS credentials (~/.aws/credentials),'

	[ -z "$AWS_ACCESS_KEY_ID" ] && AWS_ACCESS_KEY_ID="`"$AWS_CLI" configure get aws_access_key_id`"
	[ -z "$AWS_SECRET_ACCESS_KEY" ] && AWS_SECRET_ACCESS_KEY="`"$AWS_CLI" configure get aws_secret_access_key`"

	[ -z "$AWS_ACCESS_KEY_ID" ] && FATAL 'No AWS_ACCESS_KEY_ID'
	[ -z "$AWS_SECRET_ACCESS_KEY" ] && FATAL 'No AWS_SECRET_ACCESS_KEY'
fi

# Local/non-public Cloudformation additions
LOCAL_CLOUDFORMATION_DIR="$TOP_LEVEL_DIR/config/aws-cloudformation"

# CLOUDFORMATION_DIR may be given as a relative directory
findpath CLOUDFORMATION_DIR "${CLOUDFORMATION_DIR:-AWS-Cloudformation}"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'No deployment name provided'

BOSH_SSH_KEY_NAME="$DEPLOYMENT_NAME-key"

STACK_PREAMBLE_FILENAME="$AWS_CONFIG_PREFIX-preamble.json"
STACK_PREAMBLE_FILE="$CLOUDFORMATION_DIR/$STACK_PREAMBLE_FILENAME"
STACK_TEMPLATES_DIR="$CLOUDFORMATION_DIR/$STACK_TEMPLATES_DIRNAME"

[ -z "$CLOUDFORMATION_DIR" ] && FATAL 'No configuration directory supplied'
[ -d "$CLOUDFORMATION_DIR" ] || FATAL 'Configuration directory does not exist'

if [ -z "$IGNORE_MISSING_CONFIG" -a -z "$NON_AWS_DEPLOY" ]; then
	[ -z "$AWS_CONFIG_PREFIX" ] && FATAL 'No installation configuration provided'

	[ -f "$STACK_PREAMBLE_FILE" ] || FATAL "Cloudformation stack preamble '$STACK_PREAMBLE_FILE' does not exist"
	[ -d "$STACK_TEMPLATES_DIR" ] || FATAL "Cloudformation stack template directory '$STACK_TEMPLATES_DIR' does not exist"
fi

STACK_PARAMETERS_DIR="$DEPLOYMENT_DIR/parameters"
STACK_PARAMETERS_PREFIX="aws-parameters"
STACK_PARAMETERS_SUFFIX='json'

STACK_PREAMBLE_URL="file://$STACK_PREAMBLE_FILE"
STACK_PREAMBLE_OUTPUTS="$STACK_OUTPUTS_DIR/outputs-preamble.sh"



