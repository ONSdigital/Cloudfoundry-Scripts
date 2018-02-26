
. "$BASE_DIR/functions.sh"
set -x
# Check if we support colours
# When running under Jenkins TERM gets set as dumb, but tput complains with:
# tput: No value for $TERM and no -T specified
COLOURS="`tput colors -T ${TERM:-dumb} | grep -E '^[0-9]+$' || :`"

# Colours may be negative
if [ -n "$COLOURS" ] && [ $COLOURS -ge 8 ]; then
	FATAL_COLOUR="`tput setaf 1`"
	INFO_COLOUR="`tput setaf 2`"
	WARN_COLOUR="`tput setaf 3`"
	DEBUG_COLOR="`tput setaf 4`"
	# Jenkins/ansi-color adds '(B' when highlighting - this may now be fixed
	# https://issues.jenkins-ci.org/browse/JENKINS-24387
	#NORMAL_COLOUR="\e[0m"
	NORMAL_COLOUR="`tput sgr0`"
fi
set +x

[ -z "$BASE_DIR" ] && FATAL 'BASE_DIR has not been set'
[ -d "$BASE_DIR" ] || FATAL "$BASE_DIR does not exist"

# Add ability to debug commands
[ -n "$DEBUG" -a x"$DEBUG" != x"false" ] && set -x

TOP_LEVEL_DIR="$BASE_DIR/../.."
findpath TOP_LEVEL_DIR "$TOP_LEVEL_DIR"

CACHE_DIR="$TOP_LEVEL_DIR/work"
DEPLOYMENT_BASE_DIR="$TOP_LEVEL_DIR/deployment"
DEPLOYMENT_BASE_DIR_RELATIVE='deployment'
BROKER_CONFIG_DIR="$TOP_LEVEL_DIR/local/brokers"
DEPLOYMENTS_CONFIG_DIR="$TOP_LEVEL_DIR/local/deployments"
OPS_FILES_CONFIG_DIR="local/ops-files"
POST_DEPLOY_SCRIPTS_DIR="$TOP_LEVEL_DIR/local/post-scripts"

STACK_TEMPLATES_DIRNAME="Templates"

# These need to exist for findpath() to work
[ -d "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR"
[ -d "$DEPLOYMENT_BASE_DIR" ] || mkdir -p "$DEPLOYMENT_BASE_DIR"

findpath BASE_DIR "$BASE_DIR"

# Set prefix for vars that Bosh will suck in
ENV_PREFIX_NAME='CF_BOSH'
ENV_PREFIX="${ENV_PREFIX_NAME}_"

TMP_DIR="$CACHE_DIR/tmp"
BIN_DIR="$CACHE_DIR/bin"

STACK_OUTPUTS_PREFIX="outputs-"
STACK_OUTPUTS_SUFFIX='sh'

BOSH_CLI="$BIN_DIR/bosh"
CF_CLI="$BIN_DIR/cf"
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

	# Required by setup-cf_admin.sh
	BOSH_FULL_VARIABLES_STORE="$DEPLOYMENT_DIR_RELATIVE/full-var-store.yml"

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
