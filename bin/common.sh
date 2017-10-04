
. "$BASE_DIR/functions.sh"

# Check if we support colours
[ -n "$TERM" ] && COLOURS="`tput colors`"

if [ 0$COLOURS -ge 8 ]; then
	FATAL_COLOUR="`tput setaf 1`"
	INFO_COLOUR="`tput setaf 2`"
	WARN_COLOUR="`tput setaf 3`"
	DEBUG_COLOR="`tput setaf 4`"
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
BROKER_CONFIG_DIR="$BASE_DIR/../../configs/brokers"
DEPLOYMENTS_CONFIG_DIR="$BASE_DIR/../../configs/deployments"
OPS_FILES_CONFIG_DIR="$BASE_DIR/../../configs/ops-files"
TOP_LEVEL_DIR="$BASE_DIR/../.."

STACK_TEMPLATES_DIRNAME="Templates"

# These need to exist for findpath() to work
[ -d "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR"
[ -d "$DEPLOYMENT_BASE_DIR" ] || mkdir -p "$DEPLOYMENT_BASE_DIR"

findpath BASE_DIR "$BASE_DIR"
findpath CACHE_DIR "$CACHE_DIR"
findpath DEPLOYMENT_BASE_DIR "$DEPLOYMENT_BASE_DIR"
findpath TOP_LEVEL_DIR "$TOP_LEVEL_DIR"

[ -d "$BROKER_CONFIG_DIR" ] && findpath BROKER_CONFIG_DIR "$BROKER_CONFIG_DIR"
[ -d "$DEPLOYMENTS_CONFIG_DIR" ] && findpath DEPLOYMENTS_CONFIG_DIR "$DEPLOYMENTS_CONFIG_DIR"
[ -d "$OPS_FILES_CONFIG_DIR" ] && findpath OPS_FILES_CONFIG_DIR "$OPS_FILES_CONFIG_DIR"

# Set prefix for vars that Bosh will suck in
ENV_PREFIX_NAME='CF_BOSH'
ENV_PREFIX="${ENV_PREFIX_NAME}_"

TMP_DIR="$CACHE_DIR/tmp"
BIN_DIR="$CACHE_DIR/bin"

STACK_OUTPUTS_PREFIX="outputs-"
STACK_OUTPUTS_SUFFIX='sh'

BOSH="$BIN_DIR/bosh"
CF="$BIN_DIR/cf"
CA_TOOL="$BASE_DIR/ca-tool.sh"

SERVICES_SPACE="Services"

if [ -n "$DEPLOYMENT_NAME" ]; then
	grep -Eq '[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$' <<EOF || FATAL 'Invalid deployment name - no spaces are accepted and minimum two characters (alphanumeric)'
$DEPLOYMENT_NAME
EOF

	DEPLOYMENT_DIR="$DEPLOYMENT_BASE_DIR/$DEPLOYMENT_NAME"
	# Required for when the SSH key location, otherwise we end up with a full path to the SSH key that may not remain the same
	DEPLOYMENT_DIR_RELATIVE="$DEPLOYMENT_BASE_DIR_RELATIVE/$DEPLOYMENT_NAME"

	STACK_OUTPUTS_DIR="$DEPLOYMENT_BASE_DIR/$DEPLOYMENT_NAME/outputs"

	BOSH_SSH_CONFIG="$DEPLOYMENT_DIR/bosh-ssh.sh"
	BOSH_DIRECTOR_CONFIG="$DEPLOYMENT_DIR/bosh-config.sh"
	CF_CREDENTIALS="$DEPLOYMENT_DIR/cf-credentials-admin.sh"
	NETWORK_CONFIG_FILE="$DEPLOYMENT_DIR/networks.sh"
	PASSWORD_CONFIG_FILE="$DEPLOYMENT_DIR/passwords.sh"
	RELEASE_CONFIG_FILE="$DEPLOYMENT_DIR/release-config.sh"
	STEMCELL_CONFIG_FILE="$DEPLOYMENT_DIR/stemcells-config.sh"

	BOSH_LITE_STATIC_IPS_YML="$DEPLOYMENT_DIR/bosh-lite-static-ips.yml"
	BOSH_FULL_STATIC_IPS_YML="$DEPLOYMENT_DIR/bosh-full-static-ips.yml"

	AWS_PASSWORD_CONFIG_FILE="$DEPLOYMENT_DIR/aws-passwords.sh"

	# Load the environment config if we have been given one
	if [ -f "$DEPLOYMENTS_CONFIG_DIR/$DEPLOYMENT_NAME/environment.sh" ]; then
		# We want the vars in this script to be exported so that any subscript can see them, but we don't want to have all vars available
		# to all subscripts, so we turn it off again afterwards
		set -a
		. "$DEPLOYMENTS_CONFIG_DIR/$DEPLOYMENT_NAME/environment.sh"
		set +a
	fi
fi

# Set secure umask - the default permissions for ~/.bosh/config are wide open
DEBUG 'Setting secure umask'
umask 077
