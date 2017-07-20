FATAL(){
	# RHEL echo allows -e (interpret escape sequences).
	# Debian/Ubuntu/et al doesn't as it uses 'dash' as its default shell
	"$ECHO" -e "${FATAL_COLOUR}FATAL $@$NORMAL_COLOUR" >&2

	exit 1
}

WARN(){
	"$ECHO" -e "${WARN_COLOUR}WARN $@$NORMAL_COLOUR" >&2
}

INFO(){
	"$ECHO" -e "${INFO_COLOUR}INFO $@$NORMAL_COLOUR" >&2
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
		INFO "Loading '$_o'"
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
[ -n "$DEBUG" -a x"$DEBUG" != x"false" ] && set -x

CACHE_DIR="$BASE_DIR/../../work"
DEPLOYMENT_BASE_DIR="$BASE_DIR/../../deployment"
DEPLOYMENT_BASE_DIR_RELATIVE='deployment'
CONFIG_DIR="$BASE_DIR/../../configs"

# These need to exist for findpath() to work
[ -d "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR"
[ -d "$DEPLOYMENT_BASE_DIR" ] || mkdir -p "$DEPLOYMENT_BASE_DIR"

findpath BASE_DIR "$BASE_DIR"
findpath CACHE_DIR "$CACHE_DIR"
findpath DEPLOYMENT_BASE_DIR "$DEPLOYMENT_BASE_DIR"
[ -d "$CONFIG_DIR" ] && findpath CONFIG_DIR "$CONFIG_DIR"

TMP_DIR="$CACHE_DIR/tmp"
BIN_DIR="$CACHE_DIR/bin"

STACK_OUTPUTS_PREFIX="outputs-"
STACK_OUTPUTS_SUFFIX='sh'

BOSH="$BIN_DIR/bosh"
CF="$BIN_DIR/cf"
CA_TOOL="$BASE_DIR/ca-tool.sh"
