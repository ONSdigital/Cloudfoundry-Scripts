
. "$BASE_DIR/common.sh"

# Quite long winded, but we need to ensure we don't trample over any customised config
aws_region(){
	local new_aws_region="$1"

	local current_region="`\"$AWS\" configure get region`"

	# Do we need to update the config?
	if [ -n "$new_aws_region" -a x"$current_region" != x"$new_aws_region" ]; then
		if ! "$AWS" configure get region | grep -qE "^$new_aws_region"; then
			INFO 'Updating AWS CLI region configuration'
			"$AWS" configure set region "$new_aws_region"
			"$AWS" configure set output text
		fi
	else
		echo "$current_region"
	fi
}

# Quite long winded, but we need to ensure we don't trample over any customised config
aws_credentials(){
	local new_aws_access_key_id="$1"
	local new_aws_secret_access_key="$2"

	if [ -n "$new_aws_access_key_id" ]; then
		if ! "$AWS" configure get aws_access_key_id | grep -qE "^$new_aws_access_key_id"; then
			INFO 'Updating AWS CLI Access Key ID configuration'
			"$AWS" configure set aws_access_key_id "$new_aws_access_key_id"
		fi
	fi
	if [ -n "$new_aws_secret_access_key" ]; then
		if ! "$AWS" configure get aws_secret_access_key | grep -qE "^$new_aws_secret_access_key"; then
			INFO 'Updating AWS CLI Secret Access Key configuration'
			"$AWS" configure set aws_secret_access_key "$new_aws_secret_access_key"
		fi
	fi
}

parse_aws_cloudformation_outputs(){
	# We parse the outputs and parameters to build a list of the stack variables - these are then used later on
	# by the Cloudfondry deployment
	local stack="$1"

	[ -z "$stack" ] && FATAL 'No stack name/ARN provided'

	INFO 'Parsing Cloudformation outputs'
	echo '# AWS Stack output variables'
	# Debian's Awk (mawk) doesn't have gensub(), so we can't do this easily/cleanly
	#
	# Basically we convert camelcase variable names to underscore seperated names (eg FooBar -> foo_bar)
	"$AWS" --output text --query 'Stacks[*].[Parameters[*].[ParameterKey,ParameterValue],Outputs[*].[OutputKey,OutputValue]]' cloudformation describe-stacks --stack-name "$stack" | \
		perl -a -F'\t' -ne 'defined($F[1]) || next;
			chomp($F[1]);
			$F[0] =~ s/([a-z0-9])([A-Z])/\1_\2/g;
			$r{$F[0]} = sprintf("%s='\''%s'\''\n",lc($F[0]),$F[1]);
			END{ print $r{$_} foreach(sort(keys(%r))) }'
}

check_cloudformation_stack(){
	local stack_name="$1"

	[ -z "$stack_name" ] && FATAL 'No stack name provided'

	INFO 'Checking for existing Cloudformation stack'
	# Is there a better way to query?
	"$AWS" --output text --query "StackSummaries[?StackName == '$stack_name' && (StackStatus == 'CREATE_COMPLETE' || StackStatus == 'UPDATE_COMPLETE' || StackStatus == 'UPDATE_ROLLBACK_COMPLETE')].[StackName]" cloudformation list-stacks | grep -q "^$stack_name$" && INFO 'Stack found' || INFO 'Stack does not exist'
}

calculate_dns_ip(){
	local stack_outputs="$1"

	[ -z "$stack_outputs" ] && FATAL 'No stack outputs provided'
	[ -f "$stack_outputs" ] || FATAL "Stack outputs file does not exist: $stack_outputs"

	# Add AWS DNS IP: http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_DHCP_Options.html#AmazonDNS
	# "... a DNS server running on a reserved IP address at the base of the VPC IPv4 network range, plus two.
	# For example, the DNS Server on a 10.0.0.0/16 network is located at 10.0.0.2."
	#
	# Calculate the decimal version of the VPC CIDR base address then increment by 2 to find the DNS address
	local ip=`awk -F. -v increment=2 '/^vpc_cidr=/{
		gsub("^.*=[\"'\'']?","",$1)
		gsub("/.*$","",$4)

		sum=($1*256^3)+($2*256^2)+($3*256)+$4+increment

		for(i=1; i<=4; i++){
			d[i]=sum%256
			sum-=d[i]
			sum=sum/256
		}

		printf("%d.%d.%d.%d\n",d[4],d[3],d[2],d[1])
	}' "$stack_outputs"`

	[ -z "$ip" ] && FATAL 'Unable to calculate DNS IP'

	grep -qE '^[0-9.]+$' <<EOF || FATAL "Invalid IP: $IP"
$ip
EOF

	echo "dns_ip='$ip'"
}

INFO 'Setting secure umask'
umask 077

if which aws >/dev/null 2>&1; then
	AWS="`which aws`"

elif [ -f "$BIN_DIRECTORY/aws" ]; then
	AWS="$BIN_DIRECTORY/aws"

else
	FATAL "AWS cli is not installed - did you run '$BASE_DIR/install_deps.sh'?"
fi

CONFIGURED_AWS_REGION="`aws_region`"
# Provide a default - these should come from a configuration/defaults file
DEFAULT_AWS_REGION="${DEFAULT_AWS_REGION:-${CONFIGURED_AWS_REGION:-eu-central-1}}"
EXTERNAL_CIDR1="${EXTERNAL_CIDR1:-127.0.0.0/8}"
EXTERNAL_CIDR2="${EXTERNAL_CIDR2:-127.0.0.0/8}"
EXTERNAL_CIDR3="${EXTERNAL_CIDR3:-127.0.0.0/8}"

DEPLOYMENT_NAME="$1"
INSTALLATION_CONFIG="$2"
HOSTED_ZONE="${HOSTED_ZONE:-$3}"

# Configure AWS client
AWS_REGION="${AWS_REGION:-$4}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-$5}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-$6}"

# Maximum AWS Cloudformation stack size for --template-body
TEMPLATE_MAX_SIZE='51200'
MAIN_TEMPLATE_STACK_NAME='main-stack-template.json'

CLOUDFORMATION_DIR="${CLOUDFORMATION_DIR:-AWS-Cloudformation}"

# CLOUDFORMATION_DIR may be given as a relative directory
findpath CLOUDFORMATION_DIR "$CLOUDFORMATION_DIR"

DEPLOYMENT_FOLDER="$DEPLOYMENT_DIRECTORY/$DEPLOYMENT_NAME"
DEPLOYMENT_FOLDER_RELATIVE="$DEPLOYMENT_DIRECTORY_RELATIVE/$DEPLOYMENT_NAME"

[ -z "$AWS_REGION" ] && AWS_REGION="$DEFAULT_AWS_REGION"
[ -z "$DEPLOYMENT_NAME" ] && FATAL 'No deployment name provided'

# Not quite as strict as the Cloudformation check, but close enough
grep -Eq '[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$' <<EOF || FATAL 'Invalid deployment name - no spaces are accepted and minimum two characters (alphanumeric)'
$DEPLOYMENT_NAME
EOF

STACK_MAIN_FILENAME="$INSTALLATION_CONFIG.json"
STACK_MAIN_FILE="$CLOUDFORMATION_DIR/$STACK_MAIN_FILENAME"
STACK_PREAMBLE_FILENAME="$INSTALLATION_CONFIG-preamble.json"
STACK_PREAMBLE_FILE="$CLOUDFORMATION_DIR/$STACK_PREAMBLE_FILENAME"
STACK_TEMPLATES_DIRNAME="Templates"
STACK_TEMPLATES_DIR="$CLOUDFORMATION_DIR/$STACK_TEMPLATES_DIRNAME"

[ -z "$CLOUDFORMATION_DIR" ] && FATAL 'No configuration directory supplied'
[ -d "$CLOUDFORMATION_DIR" ] || FATAL 'Configuration directory does not exist'

if [ -z "$IGNORE_MISSING_CONFIG" ]; then
	[ -z "$INSTALLATION_CONFIG" ] && FATAL 'No installation configuration provided'

	[ -f "$STACK_MAIN_FILE" ] || FATAL "Cloudformation stack file '$STACK_MAIN_FILE' does not exist"
	[ -f "$STACK_PREAMBLE_FILE" ] || FATAL "Cloudformation stack preamble '$STACK_PREAMBLE_FILE' does not exist"
	[ -d "$STACK_TEMPLATES_DIR" ] || FATAL "Cloudformation stack template directory '$STACK_TEMPLATES_DIR' does not exist"
fi

STACK_PREAMBLE_URL="file://$STACK_PREAMBLE_FILE"

STACK_PREAMBLE_OUTPUTS="$DEPLOYMENT_FOLDER/outputs-preamble.sh"
STACK_MAIN_OUTPUTS="$DEPLOYMENT_FOLDER/outputs.sh"
STACK_PARAMETERS="$DEPLOYMENT_FOLDER/aws-parameters.json"

# Do we need to update the config?
aws_region "$AWS_REGION" "$STACK_MAIN_OUTPUTS"

# Do we need to update credentials?
[ -n "$AWS_ACCESS_KEY_ID" -a -n "$AWS_SECRET_ACCESS_KEY" ] && aws_credentials "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" "$STACK_MAIN_OUTPUTS"

INFO 'Checking we have the required configuration'
[ -f ~/.aws/config ] || FATAL 'No AWS config (~/.aws/config)'
[ -f ~/.aws/credentials ] || FATAL 'No AWS credentials (~/.aws/credentials)'
