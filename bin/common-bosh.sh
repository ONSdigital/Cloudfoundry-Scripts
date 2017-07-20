#!/bin/sh
#
# default vcap password c1oudc0w
#
# https://bosh.io/docs/addons-common.html#misc-users
#
# Set specific stemcell & release versions and match manifest & upload_releases_stemcells.sh

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"
	
bosh_env(){
	local action_option=$1

	"$BOSH" "$action_option" "$BOSH_LITE_MANIFEST_FILE" \
		$BOSH_INTERACTIVE_OPT \
		$BOSH_TTY_OPT \
		--var bosh_name="$DEPLOYMENT_NAME" \
		--var bosh_deployment="$BOSH_DEPLOYMENT" \
		--state="$BOSH_LITE_STATE_FILE" \
		--vars-env="$ENV_PREFIX_NAME" \
		--vars-file="$SSL_YML" \
		--vars-store="$BOSH_LITE_VARS_FILE"
}



# Set secure umask - the default permissions for ~/.bosh/config are wide open
INFO 'Setting secure umask'
umask 077

DEPLOYMENT_NAME="$1"
BOSH_FULL_MANIFEST_PREFIX="${2:-Bosh-Template}"
BOSH_CLOUD_MANIFEST_PREFIX="${3:-$BOSH_FULL_MANIFEST_NAME-AWS-CloudConfig}"
BOSH_LITE_MANIFEST_NAME="${4:-Bosh-Template}"

MANIFESTS_DIR="${5:-Bosh-Manifests}"
INTERNAL_DOMAIN="${6:-cf.internal}"

[ -n "$DEPLOYMENT_NAME" ] || FATAL 'No Bosh deployment name provided'

grep -Eiq '^([[:alnum:]]+-?[[:alnum:]])+$' <<EOF || FATAL 'Invalid domain name, must be a valid domain label'
$DEPLOYMENT_NAME
EOF

DEPLOYMENT_DIR="$DEPLOYMENT_BASE_DIR/$DEPLOYMENT_NAME"
DEPLOYMENT_DIR_RELATIVE="$DEPLOYMENT_BASE_DIR_RELATIVE/$DEPLOYMENT_NAME"

# This is also present in common-aws.sh
STACK_OUTPUTS_DIR="$DEPLOYMENT_DIR/outputs"
STACK_OUTPUTS_DIR_RELATIVE="$DEPLOYMENT_DIR_RELATIVE/outputs"

# Set prefix for vars that Bosh will suck in
ENV_PREFIX_NAME='CF_BOSH'
ENV_PREFIX="${ENV_PREFIX_NAME}_"

#
SSL_DIR="$DEPLOYMENT_DIR/ssl"
SSL_DIR_RELATIVE="$DEPLOYMENT_DIR_RELATIVE/ssl"
SSL_YML="$SSL_DIR/ssl_config.yml"
#
PASSWORD_CONFIG_FILE="$DEPLOYMENT_DIR/passwords.sh"
#
BOSH_SSH_CONFIG_FILE="$DEPLOYMENT_DIR/bosh-ssh.sh"
BOSH_CONFIG_FILE="$DEPLOYMENT_DIR/bosh-config.sh"

load_outputs "$STACK_OUTPUTS_DIR_RELATIVE" "$ENV_PREFIX"

if [ x"$multi_az" = x"true" ]; then
	BOSH_FULL_MANIFEST_NAME="$BOSH_FULL_MANIFEST_PREFIX-MultiAZ"
	BOSH_CLOUD_MANIFEST_NAME="$BOSH_CLOUD_MANIFEST_PREFIX-MultiAZ"
else
	BOSH_FULL_MANIFEST_NAME="$BOSH_FULL_MANIFEST_PREFIX"
	BOSH_CLOUD_MANIFEST_NAME="$BOSH_CLOUD_MANIFEST_PREFIX"
fi

#
BOSH_LITE_STATE_FILE="$DEPLOYMENT_DIR/$BOSH_LITE_MANIFEST_NAME-Lite-state.json"
BOSH_LITE_VARS_FILE="$DEPLOYMENT_DIR/$BOSH_LITE_MANIFEST_NAME-Lite-vars.yml"
BOSH_FULL_VARS_FILE="$DEPLOYMENT_DIR/$BOSH_FULL_MANIFEST_NAME-Full-vars.yml"

# Expand manifests dir to full path
findpath MANIFESTS_DIR "$MANIFESTS_DIR"

#
BOSH_LITE_MANIFEST_FILE="$MANIFESTS_DIR/Bosh-Lite-Manifests/$BOSH_LITE_MANIFEST_NAME.yml"
BOSH_FULL_MANIFEST_FILE="$MANIFESTS_DIR/Bosh-Full-Manifests/$BOSH_FULL_MANIFEST_NAME.yml"
BOSH_FULL_CLOUD_CONFIG_FILE="$MANIFESTS_DIR/Bosh-Full-Manifests/$BOSH_CLOUD_MANIFEST_NAME.yml"

# Check for required config
[ -d "$MANIFESTS_DIR" ] || FATAL "$MANIFESTS_DIR directory does not exist"
[ -d "$STACK_OUTPUTS_DIR" ] || FATAL "Cloud outputs directory '$STACK_OUTPUTS_DIR' does not exist"
[ -f "$BOSH_LITE_MANIFEST_FILE" ] || FATAL "Bosh lite manifest file '$BOSH_LITE_MANIFEST_FILE' does not exist"
[ -f "$BOSH_FULL_MANIFEST_FILE" ] || FATAL "Bosh manifest file '$BOSH_FULL_MANIFEST_FILE' does not exist"

# Run non-interactively?
[ -n "$INTERACTIVE" ] || BOSH_INTERACTIVE_OPT="--non-interactive"

# Without a TTY (eg within Jenkins) Bosh doesn't seem to output anything when deploying
[ -n "$NO_FORCE_TTY" ] || BOSH_TTY_OPT="--tty"

# Check we have bosh installed
installed_bin bosh

INFO 'Setting additional variables'
export ${ENV_PREFIX}internal_domain="$INTERNAL_DOMAIN"
eval domain_name="\$${ENV_PREFIX}domain_name"
eval director_dns="\$${ENV_PREFIX}director_dns"
eval deployment_name="\$${ENV_PREFIX}deployment_name"
INTERNAL_SSL_DIR="$SSL_DIR/$internal_domain"
EXTERNAL_SSL_DIR="$SSL_DIR/$domain_name"
# Used for Bosh CA cert
EXTERNAL_SSL_DIR_RELATIVE="$SSL_DIR_RELATIVE/$domain_name"

[ x"$deployment_name" = x"$DEPLOYMENT_NAME" ] || FATAL "Deployment names do not match: $deployment_name != $DEPLOYMENT_NAME"
