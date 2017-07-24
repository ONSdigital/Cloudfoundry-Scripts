

DEPLOYMENT_NAME="$1"
AWS_CONFIG_PREFIX="$2"
HOSTED_ZONE="${HOSTED_ZONE:-$3}"

# Configure AWS client
AWS_REGION="${AWS_REGION:-$4}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-$5}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-$6}"

. "$BASE_DIR/common.sh"

find_aws

[ x"$AWS_DEBUG" = x"true" ] && AWS_DEBUG_OPTION='--debug'

AWS_PROFILE="${AWS_PROFILE:-default}"

CONFIGURED_AWS_REGION="`aws_region`"
# Provide a default - these should come from a configuration/defaults file
DEFAULT_AWS_REGION="${DEFAULT_AWS_REGION:-${CONFIGURED_AWS_REGION:-eu-central-1}}"

# CLOUDFORMATION_DIR may be given as a relative directory
findpath CLOUDFORMATION_DIR "${CLOUDFORMATION_DIR:-AWS-Cloudformation}"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'No deployment name provided'

STACK_PREAMBLE_FILENAME="$AWS_CONFIG_PREFIX-preamble.json"
STACK_PREAMBLE_FILE="$CLOUDFORMATION_DIR/$STACK_PREAMBLE_FILENAME"
STACK_TEMPLATES_DIR="$CLOUDFORMATION_DIR/$STACK_TEMPLATES_DIRNAME"

[ -z "$CLOUDFORMATION_DIR" ] && FATAL 'No configuration directory supplied'
[ -d "$CLOUDFORMATION_DIR" ] || FATAL 'Configuration directory does not exist'

if [ -z "$IGNORE_MISSING_CONFIG" ]; then
	[ -z "$AWS_CONFIG_PREFIX" ] && FATAL 'No installation configuration provided'

	[ -f "$STACK_PREAMBLE_FILE" ] || FATAL "Cloudformation stack preamble '$STACK_PREAMBLE_FILE' does not exist"
	[ -d "$STACK_TEMPLATES_DIR" ] || FATAL "Cloudformation stack template directory '$STACK_TEMPLATES_DIR' does not exist"
fi

STACK_PARAMETERS_DIR="$DEPLOYMENT_DIR/parameters"
#STACK_PARAMETERS_DIR_RELATIVE="$DEPLOYMENT_DIR_RELATIVE/parameters"
STACK_PARAMETERS_PREFIX="aws-parameters"
STACK_PARAMETERS_SUFFIX='json'

STACK_PREAMBLE_URL="file://$STACK_PREAMBLE_FILE"
STACK_PREAMBLE_OUTPUTS="$STACK_OUTPUTS_DIR/outputs-preamble.sh"

if [ -z "$AWS_REGION" ]; then
	AWS_REGION="$DEFAULT_AWS_REGION"
else
	# Do we need to update the config?
	aws_region "$AWS_REGION"
fi

# Do we need to update credentials?
[ -n "$AWS_ACCESS_KEY_ID" -a -n "$AWS_SECRET_ACCESS_KEY" ] && aws_credentials "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY"

INFO 'Checking we have the required configuration'
[ -f ~/.aws/config ] || FATAL 'No AWS config (~/.aws/config)'
[ -f ~/.aws/credentials ] || FATAL 'No AWS credentials (~/.aws/credentials)'
