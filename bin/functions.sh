
FATAL(){
	# RHEL echo allows -e (interpret escape sequences).
	# Debian/Ubuntu/et al doesn't as it uses 'dash' as its default shell
	"$ECHO" -e "`_date` ${FATAL_COLOUR}FATAL $@$NORMAL_COLOUR" >&2

	exit 1
}

WARN(){
	"$ECHO" -e "`_date` ${WARN_COLOUR}WARN $@$NORMAL_COLOUR" >&2
}

INFO(){
	"$ECHO" -e "`_date` ${INFO_COLOUR}INFO $@$NORMAL_COLOUR" >&2
}

_date(){
	date +"%F %T %Z"
}

DEBUG(){
	[ -z "$DEBUG" -o x"$DEBUG" = x"false" ] && return 0

	"$ECHO" -e "`_date` ${DEBUG_COLOUR}DEBUG $@$NORMAL_COLOUR" >&2
}

post_deploy_scripts(){
	local subdir="$1"

	[ -d "$POST_DEPLOY_SCRIPTS_DIR/$subdir" ] || return 0

	INFO "Running $subdir post deployment scripts"
	find "$POST_DEPLOY_SCRIPTS_DIR/$subdir" -maxdepth 1 -mindepth 1 -exec /bin/sh "{}" \;
}

calculate_dns(){
	local vpc_cidr="$1"

	[ -z "$vpc_cidr" ] && FATAL 'No VPC CIDR provided'

	local vpc_base_address="`echo $1 | awk -F/ '{print $1}'`"
	local vpc_decimal_dns_address="`ip_to_decimal "$vpc_base_address"`"
	local vpc_dns_ip="`decimal_to_ip "$vpc_decimal_dns_address" 2`"

	"$ECHO" "dns_ip='$vpc_dns_ip'"
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
	local stack_json="$1"
	local search_regex="$2"

	[ -n "$stack_json" ] || FATAL 'No Cloudformation stack JSON file provided'
	[ -f "$stack_json" ] || FATAL "Cloudformation stack JSON file does not exist: '$stack_json'"
	[ -n "$search_regex" ] || FATAL 'No search regex provided'

	# This assumes the AWS Cloudformation template is 'correctly' indented using two spaces per indent
	awk -v search_regex="$search_regex" \
		'{if($0 ~ /^  "Parameters"/){ o=1 }else if($0 ~ /^  "/){ o=0} if(o && /^    "/){ gsub("[\"{:]","",$1); if($1 ~ search_regex) print $1 } }' "$stack_json"
}

generate_parameters_file(){
	local stack_json="$1"

	[ -n "$stack_json" ] || FATAL 'No Cloudformation stack JSON file provided'
	[ -f "$stack_json" ] || FATAL "Cloudformation stack JSON file does not exist: '$stack_json'"

	echo '['
	for _key in `awk '{if($0 ~ /^  "Parameters"/){ o=1 }else if($0 ~ /^  "/){ o=0} if(o && /^    "/){ gsub("[\"{:]","",$1); print $1 } }' "$stack_json"`; do
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
	perl -ne 's/([a-z0-9])([A-Z])/\1_\2/g; print uc($_)'
}

# decapitalise/uncapitalise doesn't sound 100% correct as it sounds as if they would revert back to original case
lowercase_aws(){
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

	for _key in `awk '{if($0 ~ /^  "Parameters"/){ o=1 }else if($0 ~ /^  "/){ o=0} if(o && /^    "/){ gsub("[\"{:]","",$1); print $1 } }' "$stack_json"`; do
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

	diff -q "$updated_parameters" "$parameters_file" || mv -f "$updated_parameters" "$parameters_file"

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

bosh_lite(){
	local action_option="$1"
	local bosh_manifest="$2"

	[ -z "$action_option" ] && FATAL 'No action provided'
	[ -z "$bosh_manifest" ] && FATAL 'No Bosh manifest provided'
	[ -f "$bosh_manifest" ] || FATAL "Unable to find: $bosh_manifest"

	shift 2

	[ -n "$PUBLIC_BOSH_LITE_OPS_FILE" ] && local ops_file_option="$ops_file_option --ops-file=$PUBLIC_BOSH_LITE_OPS_FILE"
	[ -n "$PRIVATE_BOSH_LITE_OPS_FILE" ] && local ops_file_option="$ops_file_option --ops-file=$PRIVATE_BOSH_LITE_OPS_FILE"

	_bosh "$action_option" "$bosh_manifest" "$@"
}

bosh_full(){
	local action_option="$1"
	local bosh_manifest="$2"

	[ -z "$action_option" ] && FATAL 'No action provided'
	[ -z "$bosh_manifest" ] && FATAL 'No Bosh manifest provided'
	[ -f "$bosh_manifest" ] || FATAL "Unable to find: $bosh_manifest"

	shift 2

	[ -n "$PUBLIC_BOSH_FULL_OPS_FILE" ] && local ops_file_option="$ops_file_option --ops-file=$PUBLIC_BOSH_FULL_OPS_FILE"
	[ -n "$PRIVATE_BOSH_FULL_OPS_FILE" ] && local ops_file_option="$ops_file_option --ops-file=$PRIVATE_BOSH_FULL_OPS_FILE"

	_bosh "$action_option" "$bosh_manifest" "$@"
}

_bosh(){
	local action="$1"
	local bosh_manifest="$2"

	[ -z "$action_option" ] && FATAL 'No action provided'
	[ -z "$bosh_manifest" ] && FATAL 'No Bosh manifest provided'

	shift 2

	# --vars-errs is ignored for 'bosh create-env'
	if [ x"$action" = x'create-env' -o x"$action" = x'delete-env' ]; then
		local state_option="--state=$BOSH_LITE_STATE_FILE"
	else
		local vars_errs_option='--vars-errs'
	fi

	# We don't always want to process the ops file(s)
	[ 0"$NO_OPS_FILE" -eq 1 ] && unset ops_file_option

	# 
	if [ x"$action" = x'interpolate' -o x"$action" = x'int' ] || [ -n "$DEBUG" -a x"$DEBUG" != x"false" ]; then
		echo '---'
		"$BOSH_CLI" interpolate "$bosh_manifest" \
			$ops_file_option \
			--no-color \
			$@ \
			--var-errs \
			--vars-env=$ENV_PREFIX_NAME

		[ x"$action" = x'interpolate' -o x"$action" = x'int' ] && return
	fi

	INFO "Running 'bosh $action'"
	"$BOSH_CLI" "$action" "$bosh_manifest" \
		$BOSH_TTY_OPT \
		$ops_file_option \
		$vars_errs_option \
		$state_option \
		$@ \
		--vars-env=$ENV_PREFIX_NAME
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

	if which realpath >/dev/null 2>&1; then
		# Newer Linux distributions have realpath
		real_dir="`realpath \"$path\"`"

	elif readlink --version 2>&1 | grep -q 'GNU GPL'; then
		# Older ones should have readlink -k
		real_dir="`readlink -f \"$path\"`"
	fi

	if [ -z "$real_dir" ]; then
		# Everything else falls here
		[ -d "$path" ] || path="`dirname \"$path\"`"

		real_dir="`cd \"$path\" && pwd`"
	fi

	[ x"$return_var" != x"NONE" ] && eval $return_var="\"$real_dir\"" || echo "$real_dir"
}

prefix_vars(){
	local parse_file="$1"
	local env_prefix="$2"

	[ -n "$parse_file" -a x"$parse_file" != x"-" -a ! -f "$parse_file" ] && FATAL "Unable to parse missing file: $parse_file"

	# This should cope with both env_prefix and parse_file being empty
	awk -v env_prefix="$env_prefix" '!/^#/{printf("%s%s\n",env_prefix,$0)}' "$parse_file"
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

		eval export `prefix_vars "$outputs_dir/$_o" "$env_prefix"`
	done
}

load_output_vars(){
	local stack_outputs_dir="$1"
	local env_prefix="$2"

	local outputs_dir

	[ -z "$3" ] && FATAL 'Not enough parameters'
	[ -z "$stack_outputs_dir" ] && FATAL 'No stack outputs directory provided'

	# Find the absolute path
	findpath outputs_dir "$stack_outputs_dir"

	[ -d "$outputs_dir" ] || FATAL "Stack outputs directory does not exist: '$outputs_dir'"

	[ x"$env_prefix" = x"NONE" ] && unset env_prefix
	shift 2

	for _i in $@; do
		eval `grep -hE "^$_i=" "$outputs_dir"/* | prefix_vars - "$env_prefix"`
	done
}

# Hopefully we can run on Linux and Darwin (OSX)
case `uname -s` in
	Darwin)
		ECHO='echo'
		SED_EXTENDED='-E'
		;;
	Linux)
		# Debian & Ubuntu use 'dash' as their shell, which is less than feature complete compared to other shells
		ECHO='/bin/echo'
		SED_EXTENDED='-r'
		;;
esac

