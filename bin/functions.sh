# The various JSON parsing elements assume the JSON is perfectly indented.  Failing to do so will break things.  We
# could pipe the JSON via 'python -m json.tool'....

_date(){
	date +"%F %T %Z"
}

FATAL(){
	# Printf is slightly more cross platform than using 'echo'.  Some echos expand escape sequences by default,
	# some require -e to do so whereas others ignore the option and just print -e
	printf "%s" `_date` >&2
	cat >&2 <<EOF
${FATAL_COLOR}FATAL $@${NORMAL_COLOUR}
EOF

	exit 1
}

WARN(){
	printf "%s" `_date` >&2
	cat >&2 <<EOF
${WARN_COLOUR}WARN $@${NORMAL_COLOUR}
EOF
}

INFO(){
	printf "%s" `_date` >&2
	cat >&2 <<EOF
${INFO_COLOUR}INFO $@${NORMAL_COLOUR}
EOF
}

DEBUG(){
	[ -z "$DEBUG" -o x"$DEBUG" = x"false" ] && return 0

	printf "%s" `_date` >&2
	cat >&2 <<EOF
${DEBUG_COLOUR}DEBUG $@${NORMAL_COLOUR}
EOF
}

post_deploy_scripts(){
	local subdir="$1"

	[ -d "$POST_DEPLOY_SCRIPTS_DIR/$subdir" ] || return 0

	INFO "Running $subdir post deployment scripts"
	find "$POST_DEPLOY_SCRIPTS_DIR/$subdir" -maxdepth 1 -mindepth 1 -exec /bin/sh "{}" \;
}

update_yml_var(){
	local file="$1"
	local var="$2"
	local value="$3"

	[ -z "$value" ] && FATAL 'Not enough parameters'

	if [ ! -f "$file" ]; then
		echo --- >"$file"
	else
		local existing_file=1
	fi

	if [ -n "$existing_file" ] && grep -Eq "^$var: \"$value\"$" "$file"; then
		INFO "Updating local $_r url"
		sed -i $SED_EXTENDED -e "s|^($var): .*$|\1: \"$value\"|g" "$file"
	else
		INFO "Adding local $_r url"
		echo "$var: \"$value\"" >>"$file"
	fi
}

export_file_vars(){
	local file="$1"
	# env_prefix may be empty
	local env_prefix="$2"

	[ -n "$file" ] || FATAL 'No file provided'
	[ -f "$file" ] || FATAL "$file does not exist"

	for _var in `awk -F= '!/^#/{print $1}' "$file"`; do
		eval `awk -v var="$_var" -v prefix="$env_prefix" 'BEGIN{ regex=sprintf("^%s=",var) }{ if($0 ~ regex) printf("export %s%s",prefix,$0) }' "$file"`
	done
}

calculate_dns(){
	local vpc_cidr="$1"

	[ -z "$vpc_cidr" ] && FATAL 'No VPC CIDR provided'

	local vpc_base_address="`echo $1 | awk -F/ '{print $1}'`"
	local vpc_decimal_dns_address="`ip_to_decimal "$vpc_base_address"`"
	local vpc_dns_ip="`decimal_to_ip "$vpc_decimal_dns_address" 2`"

	printf "dns_ip='%s'\n" "$vpc_dns_ip"
}

ip_to_decimal(){
	echo $1 | awk -F. '{sum=$4+($3*256)+($2*256^2)+($1*256^3)}END{printf("%d\n",sum)}'
}

decimal_to_ip(){
	[ -n "$2" ] && value="`expr $1 + $2`" || value="$1"

	# Urgh
	echo $value | awk '{address=$1; for(i=1; i<=4; i++){d[i]=address%256; address-=d[i]; address=address/256;} for(j=1; j<=4; j++){ printf("%d",d[5-j]);if( j==4 ){ printf("\n") }else{ printf(".")}}}'
}


stack_file_name(){
	local deployment_name="$1"
	local stack_file="$2"

	[ -z "$stack_file" ] && FATAL 'Not enough parameters'

	echo "$deployment_name-`echo $stack_file | sed $SED_EXTENDED -e "s/^$AWS_CONFIG_PREFIX-//g" -e 's/\.json$//g'`"
}

check_aws_key(){
	local keyname="$1"

	[ -z "$keyname" ] && FATAL 'No keyname provided'

	# Check if we have an existing AWS SSH key that has the correct name
	"$AWS_CLI" ec2 describe-key-pairs --key-names "$keyname" >/dev/null 2>&1 || return 1
}

delete_aws_key(){
	local keyname="$1"

	if check_aws_key "$keyname"; then
		INFO 'Deleting AWS SSH key'
		"$AWS_CLI" ec2 delete-key-pair --key-name "$keyname"
	else
		WARN "AWS SSH key does not exist: $keyname"
	fi
}

find_aws(){
	if which aws >/dev/null 2>&1; then
		AWS_CLI="`which aws`"

	elif [ -f "$BIN_DIR/aws" ]; then
		AWS_CLI="$BIN_DIR/aws"

	else
		FATAL "AWS cli is not installed - did you run '$BASE_DIR/install_deps.sh'?"
	fi
}


validate_json_files(){
	local failure=0

	for _j in $@; do
		[ -f "$_j" ] || FATAL "File does not exist: '$_j'"

		INFO "Validating JSON: '$_j'"
		python -m json.tool "$_j" >/dev/null || FATAL 'JSON failed to validate'
	done
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
	"$AWS_CLI" --output text --query 'Stacks[*].[Parameters[*].[ParameterKey,ParameterValue],Outputs[*].[OutputKey,OutputValue]]' \
		cloudformation describe-stacks --stack-name "$stack" | perl -a -F'\t' -ne 'defined($F[1]) || next;
		chomp($F[1]);
		$F[0] =~ s/([a-z0-9])([A-Z])/\1_\2/g;
		$r{$F[0]} = sprintf("%s='\''%s'\''\n",lc($F[0]),$F[1]);
		END{ print $r{$_} foreach(sort(keys(%r))) }'
}

find_aws_parameters(){
	default_regex='^[A-Za-z0-9]+$'

	local stack_json="$1"
	local search_regex="${2:-$default_regex}"

	[ -n "$stack_json" ] || FATAL 'No Cloudformation stack JSON file provided'
	[ -f "$stack_json" ] || FATAL "Cloudformation stack JSON file does not exist: '$stack_json'"

	# This assumes the AWS Cloudformation template is 'correctly' indented using two spaces per indent
	awk -v search_regex="$search_regex" \
		'{if($0 ~ /^  "Parameters"/){ o=1 }else if($0 ~ /^  "/){ o=0} if(o && /^    "/){ gsub("[\"{:]","",$1); if($1 ~ search_regex) print $1 } }' "$stack_json"
}

# Quite badly named as if does more than check existing parameters
check_existing_parameters(){
	local stack_json="$1"

	[ -n "$stack_json" ] || FATAL 'No Cloudformation stack JSON file provided'
	[ -f "$stack_json" ] || FATAL "Cloudformation stack JSON file does not exist: '$stack_json'"

	# Retain existing parameters
	for varname in `find_aws_parameters "$stack_json"`; do
		# DeploymentName -> DEPLOYMENT_NAME
		upper_varname="`echo $varname | capitalise_aws`"
		# DEPLOYMENT_NAME -> deployment_name
		lower_varname="`echo $upper_varname | tr '[[:upper:]]' '[[:lower:]]'`"

		# Variable from AWS outputs
		eval lower_value="\$$lower_varname"

		# Environmental variable
		eval upper_value="\$$upper_varname"

		[ x"$lower_value" = x'$' ] && unset lower_value
		[ x"$upper_value" = x'$' ] && unset upper_value

		echo "$lower_varname" | grep -Eq '_password$' && password=1

		# Check if this is a password and if we need to re/generate a password
		if [ 0$password -eq 1 ] && [ -z "$lower_value" -o x"$IGNORE_EXISTING_PASSWORDS" = x'true' ]; then
			INFO "Generating new password for $varname"
			updated_value="`generate_password 32`"

		# Do we need to reset the MultiAz option?
		# Have we been given an updated value?
		elif [ x"$lower_varname" = x'availability:' -a x"$IGNORE_EXISTING_AVAILABILITY_CONFIG" = x'true' ] ||
			[ -n "$upper_value" -a x"$IGNORE_EXISTING_PARAMETERS" = x'true' ]; then

			INFO "Setting $varname to $upper_value"
			updated_value="$upper_value"

		elif [ -n "$lower_value" ]; then
			[ 0$password -eq 1 ] && redacted='[REDACTED]'

			DEBUG "Retaining $varname value ${redacted:-$lower_value}"
			updated_value="$lower_value"
		fi

		# Only update if we have a value
		[ -n "$updated_value" ] && eval "$upper_varname"="$updated_value"

		unset password redacted updated_value
	done
}

generate_parameters_file(){
	local stack_json="$1"

	[ -n "$stack_json" ] || FATAL 'No Cloudformation stack JSON file provided'
	[ -f "$stack_json" ] || FATAL "Cloudformation stack JSON file does not exist: '$stack_json'"

	echo '['
	for _key in `find_aws_parameters "$stack_json"`; do
		local var_name="`echo $_key | capitalise_aws`"
		eval _param="\$$var_name"

		[ -z "$_param" -o x"$_param" = x'$' ] && continue

		# Correctly indented, One tab indentation for HEREDOC
		cat <<EOF
	{ "ParameterKey": "$_key", "ParameterValue": "$_param" }
EOF
		unset var var_name
	done | awk '{ line[++i]=$0 }END{ for(l=1; l<=i; l++){ if(i == l){ print line[l] }else{ printf("%s,\n",line[l]) } } }'
	echo ']'

}

capitalise_aws(){
	# Turn FooBarBaz -> FOO_BAR_BAZ
	perl -ne 's/([a-z0-9])([A-Z])/\1_\2/g; print uc($_)'
}

englishify_aws(){
	# Turn FooBarBaz -> Foo Bar Baz
	perl -ne 's/([a-z0-9])([A-Z])/\1 \2/g; print $_'
}

englishify(){
	# FOO_BAR_BAZ -> Foo Bar Baz
	perl -ne 's/([A-Z0-9])([A-Za-z0-9]+)(_|$)/\1\L\2 /g; s/ $//g; print $_'
}

# decapitalise/uncapitalise doesn't sound 100% correct as it sounds as if they would revert back to original case
lowercase_aws(){
	# Turn FooBarBaz -> foo_bar_baz
	perl -ne 's/([a-z0-9])([A-Z])/\1_\2/g; print lc($_)'
}

update_parameters_file(){
	local stack_json="$1"
	local parameters_file="$2"

	[ -n "$stack_json" ] || FATAL 'No Cloudformation stack JSON file provided'
	[ -f "$stack_json" ] || FATAL "Cloudformation stack JSON file does not exist: '$stack_json'"
	[ -n "$parameters_file" ] || FATAL 'No Cloudformation parameters file provided'
	[ -f "$parameters_file" ] || FATAL "Cloudformation parameters file does not exist: '$parameters_file'"

	findpath stack_json "$stack_json"
	findpath parameters_file "$parameters_file"

	local updated_parameters="`mktemp "$parameters_file.XXXX"`"

	for _key in `find_aws_parameters "$stack_json"`; do
		var_name="`echo $_key | capitalise_aws`"
		eval _value="\$$var_name"

		echo "$_key:$_value" | grep -qE '#' && local separator='@' || local separator='#'

		# Beware, some of these greps are silent and some are not!
		if [ -z "$_value" -o x"$_value" = x'$' ]; then
			DEBUG "No value provided for key $_key"
			# No value provided, so cannot update, so see if we have an existing entry we can retain
			grep -E "\"ParameterKey\": \"$_key\"" "$parameters_file" && DEBUG "Retaining existing value for $_key" || :

		elif grep -Eq "\"ParameterKey\": \"$_key\"" "$parameters_file"; then
			# ... update an existing entry
			DEBUG "Updating key $_key with value $_value"
			sed $SED_EXTENDED -ne "s$separator\"(ParameterKey)\": \"($_key)\", \"(ParameterValue)\": \".*\"$separator\"\1\": \"\2\", \"\3\": \"$_value\"${separator}gp" \
				"$parameters_file"
		else
			# ... add a new entry
			DEBUG "Adding new key $_key with value $_value"
			cat <<EOF
	{ "ParameterKey": "$_key", "ParameterValue": "$_value" }
EOF
		fi

		unset var var_name
	done | awk '{ gsub(/, *$/,""); params[++i]=$0 }END{ printf("[\n"); for(j=1; j<=i; j++){ printf("%s%s\n",params[j],i==j ? "" : ",") } printf("]\n")}' >"$updated_parameters"

	if diff -q "$updated_parameters" "$parameters_file"; then
		INFO 'No update required'
	else
		INFO 'Updating'
		mv -f "$updated_parameters" "$parameters_file"
	fi

	[ -f "$parameters_file" ] && rm -f "$updated_parameters" || :
}

stack_exists(){
	# Checks if a stack exists
	local stack_name="$1"

	[ -z "$stack_name" ] && FATAL 'No stack name provided'

	"$AWS_CLI" --output text --query "StackSummaries[?StackName == '$stack_name' && StackStatus != 'DELETE_COMPLETE'].StackName" \
		cloudformation list-stacks | grep -Eq "^$stack_name"
}

check_cloudformation_stack(){
	# Checks if a stack is in a state that we can run an update on
	local stack_name="$1"

	[ -z "$stack_name" ] && FATAL 'No stack name provided'

	INFO "Checking for existing Cloudformation stack: $stack_name"
	# Is there a better way to query?
	if "$AWS_CLI" --output text --query "StackSummaries[?StackName == '$stack_name'].[StackName]" \
		cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE | grep -Eq "^$stack_name$"; then

		INFO "Stack found: $stack_name"

		local rc=0
	elif "$AWS_CLI" --output text --query "StackSummaries[?StackName == '$stack_name'].[StackName]" cloudformation list-stacks --stack-status-filter DELETE_FAILED \
		| grep -Eq "^$stack_name$"; then

		FATAL 'Stack is in DELETE_FAILED state. Please manually fix the issues and finish deleting the stack'
	else
		INFO "Stack does not exist: $stack_name"

		local rc=1
	fi

	return $rc
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

show_duplicate_output_names(){
	local outputs_dir="$1"

	awk -F= '!/^#/{ a[$1]++ }END{ for(i in a){ if(a[i] > 1) printf("%s=%d\n",i,a[i])}}' "$outputs_dir"/outputs-*.sh
}

cf_app_url(){
	local application="$1"

	[ -z "$application" ] && FATAL 'No application provided'

	# We blindly assume we are logged in and pointing at the right place
	# Sometimes we seem to get urls, sometimes routes?
	"$CF_CLI" app "$application" | awk -F" *: *" '/^(urls|routes):/{print $2}'
}



installed_bin(){
	local bin="$1"

	[ -z "$bin" ] && FATAL 'No binary to check'

	[ -f "$BIN_DIR/$bin" ] || FATAL "$bin has not been installed, did you run $BASE_DIR/install_deps.sh?"

	if [ ! -x "$BIN_DIR/$bin" ]; then
		WARN "$bin is not executable - fixing permissions"

		chmod u+x "$BIN_DIR/$bin"
	fi
}

findpath(){
	local return_var="$1"

	[ -z "$2" ] && FATAL 'Not enough parameters provided'
	shift

	local path="$@"

	[ -z "$path" ] && FATAL 'No path to find'
	[ -e "$path" ] || FATAL "Path does not exist: $path"

	local real_dir=

	if [ x"$_findpath" = x'realpath' ] || which realpath >/dev/null 2>&1; then
		# Newer Linux distributions have realpath
		real_dir="`realpath \"$path\"`"

		_findpath='realpath'

	elif [ x"$_findpath" = x'reallink' ] || readlink --version 2>&1 | grep -q 'GNU GPL'; then
		# Older ones should have readlink -k
		real_dir="`readlink -f \"$path\"`"


		_findpath='reallink'
	fi

	# If we fail to find real_dir, or we lack realpath/readlink, we'll run this as a last resort
	if [ -z "$real_dir" ]; then
		# Everything else falls here
		[ -d "$path" ] || path="`dirname \"$path\"`"

		real_dir="`cd \"$path\" && pwd`"
	fi

	[ x"$return_var" != x"NONE" ] && eval $return_var="\"$real_dir\"" || echo "$real_dir"
}


generate_password(){
	local length="${1:-16}"
	local tr_filter="${2:-[:alnum:]}"

	head /dev/urandom | tr -dc "$tr_filter" | head -c "$length"
}

load_outputs(){
	local stack_outputs_dir="$1"
	local env_prefix="$2"

	local outputs_dir

	[ -z "$stack_outputs_dir" ] && FATAL 'No stack outputs directory provided'

	# Find the absolute path
	findpath outputs_dir "$stack_outputs_dir"

	[ -d "$outputs_dir" ] || FATAL "Stack outputs directory does not exist: '$outputs_dir'"

	INFO "Loading outputs"
	for _o in `find "$outputs_dir/" -mindepth 1 -maxdepth 1 "(" -not -name outputs-preamble.sh -and -name \*.sh ")" | awk -F/ '{print $NF}' | sort`; do
		DEBUG "Loading '$_o'"
		if ! grep -Eq '^[^#]' "$outputs_dir/$_o"; then
			DEBUG "Not loading empty '$_o'"

			continue
		fi

		export_file_vars "$outputs_dir/$_o" "$env_prefix"
	done
}

# Hopefully we can run on Linux and Darwin (OSX)
case `uname -s` in
	Darwin)
		SED_EXTENDED='-E'
		;;
	Linux)
		# Debian & Ubuntu use 'dash' as their shell, which is less than feature complete compared to other shells
		SED_EXTENDED='-r'
		;;
esac

