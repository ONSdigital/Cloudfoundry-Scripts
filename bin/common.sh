FATAL(){
	# RHEL echo allows -e (interpret escape sequences).
	# Debian/Ubuntu/et al doesn't as it uses 'dash' as its default shell
	/bin/echo -e "${FATAL_COLOUR}FATAL $@$NORMAL_COLOUR" >&2

	exit 1
}

WARN(){
	/bin/echo -e "${WARN_COLOUR}WARN $@$NORMAL_COLOUR" >&2
}

INFO(){
	/bin/echo -e "${INFO_COLOUR}INFO $@$NORMAL_COLOUR" >&2
}


installed_bin(){
	local bin="$1"

	[ -z "$bin" ] && FATAL 'No binary to check'

	[ -f "$BIN_DIRECTORY/$bin" ] || FATAL "$bin has not been installed, did you run $BASE_DIR/install_deps.sh?"

	if [ ! -x "$BIN_DIRECTORY/$bin" ]; then
		WARN "$bin is not executable - fixing permissions"

		chmod u+x "$BIN_DIRECTORY/$bin"
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

parse_aws_credentials(){
	[ -f ~/.aws/credentials ] || FATAL 'AWS credentials file does not exist ~/.aws/credentials'

	awk -F' ?= ?' '{
		if(/^\[default\]$/){
			def=1
		}else if(/^aws_access_key_id = / && def == 1){
			printf("aws_access_key_id=\"%s\"\n",$2)
			key=1
		}else if(/^aws_secret_access_key = / && def == 1){
			printf("aws_secret_access_key=\"%s\"\n",$2)
			secret=1
		}else{
			def=0
		}
	}END{
		if(key != 1 || secret != 1)
			exit 1

		exit 0
	}' ~/.aws/credentials || FATAL 'Unable to find aws_access_key_id & aws_secret_access_key from ~/.aws/credentials'
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


# Check if we support colours
[ -n "$TERM" ] && COLOURS="`tput colors`"

if [ 0$COLOURS -ge 8 ]; then
	FATAL_COLOUR="`tput setaf 1`"
	WARN_COLOUR="`tput setaf 3`"
	INFO_COLOUR="`tput setaf 2`"
	# Jenkins/ansi-color adds '(B' when highlighting
	# https://issues.jenkins-ci.org/browse/JENKINS-24387
	#NORMAL_COLOUR="`tput sgr0`"
	NORMAL_COLOUR="\e[0m"
fi

[ -z "$BASE_DIR" ] && FATAL 'BASE_DIR has not been set'
[ -d "$BASE_DIR" ] || FATAL "$BASE_DIR does not exist"

# Add ability to debug commands
[ -n "$DEBUG" ] && set -x

CACHE_DIRECTORY="$BASE_DIR/../../work"
DEPLOYMENT_DIRECTORY="$BASE_DIR/../../deployment"
DEPLOYMENT_DIRECTORY_RELATIVE='deployment'

# These need to exist for findpath() to work
[ -d "$CACHE_DIRECTORY" ] || mkdir -p "$CACHE_DIRECTORY"
[ -d "$DEPLOYMENT_DIRECTORY" ] || mkdir -p "$DEPLOYMENT_DIRECTORY"

findpath BASE_DIR "$BASE_DIR"
findpath CACHE_DIRECTORY "$CACHE_DIRECTORY"
findpath DEPLOYMENT_DIRECTORY "$DEPLOYMENT_DIRECTORY"

TMP_DIRECTORY="$CACHE_DIRECTORY/tmp"
BIN_DIRECTORY="$CACHE_DIRECTORY/bin"

BOSH="$BIN_DIRECTORY/bosh"
CF="$BIN_DIRECTORY/cf"
CA_TOOL="$BASE_DIR/ca-tool.sh"
