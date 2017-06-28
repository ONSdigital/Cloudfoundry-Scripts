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
	
check_aws_keys(){
	[ -n "$aws_access_key_id" ] || FATAL 'No AWS access key ID provided'
	[ -n "$aws_secret_access_key" ] || FATAL 'No AWS secret access key provided'
}

bosh_env(){
	local action_option=$1

	"$BOSH" "$action_option" "$BOSH_LITE_MANIFEST_FILE" \
		$BOSH_INTERACTIVE_OPT \
		$BOSH_TTY_OPT \
		--var bosh_name="$DEPLOYMENT_NAME" \
		--var bosh_deployment="$BOSH_DEPLOYMENT" \
		--var aws_access_key_id="$aws_access_key_id" \
		--var aws_secret_access_key="$aws_secret_access_key" \
		--state="$BOSH_LITE_STATE_FILE" \
		--vars-env="$ENV_PREFIX_NAME" \
		--vars-file="$SSL_YML" \
		--vars-store="$BOSH_LITE_VARS_FILE"
}

# Set secure umask - the default permissions for ~/.bosh/config are wide open
INFO 'Setting secure umask'
umask 077

DEPLOYMENT_NAME="$1"
BOSH_FULL_MANIFEST_NAME="${2:-Bosh-Template}"
BOSH_CLOUD_MANIFEST_NAME="${3:-$BOSH_FULL_MANIFEST_NAME-AWS-CloudConfig}"
BOSH_LITE_MANIFEST_NAME="${4:-$BOSH_FULL_MANIFEST_NAME}"

AWS_ACCESS_KEY_ID="${5:-$AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${6:-$AWS_SECRET_ACCESS_KEY}"

MANIFESTS_DIR="${7:-Bosh-Manifests}"
INTERNAL_DOMAIN="${8:-cf.internal}"

[ -n "$DEPLOYMENT_NAME" ] || FATAL 'No Bosh deployment name provided'

grep -Eiq '^([[:alnum:]]+-?[[:alnum:]])+$' <<EOF || FATAL 'Invalid domain name, must be a valid domain label'
$DEPLOYMENT_NAME
EOF

# Expand manifests dir to full path
findpath MANIFESTS_DIR "$MANIFESTS_DIR"

#
DEPLOYMENT_FOLDER="$DEPLOYMENT_DIRECTORY/$DEPLOYMENT_NAME"
DEPLOYMENT_FOLDER_RELATIVE="$DEPLOYMENT_DIRECTORY_RELATIVE/$DEPLOYMENT_NAME"

#
BOSH_LITE_STATE_FILE="$DEPLOYMENT_FOLDER/$BOSH_LITE_MANIFEST_NAME-Lite-state.json"
BOSH_LITE_VARS_FILE="$DEPLOYMENT_FOLDER/$BOSH_LITE_MANIFEST_NAME-Lite-vars.yml"
BOSH_FULL_VARS_FILE="$DEPLOYMENT_FOLDER/$BOSH_FULL_MANIFEST_NAME-Full-vars.yml"
#
BOSH_LITE_MANIFEST_FILE="$MANIFESTS_DIR/Bosh-Lite-Manifests/$BOSH_LITE_MANIFEST_NAME.yml"
BOSH_FULL_MANIFEST_FILE="$MANIFESTS_DIR/Bosh-Full-Manifests/$BOSH_FULL_MANIFEST_NAME.yml"
BOSH_FULL_CLOUD_CONFIG_FILE="$MANIFESTS_DIR/Bosh-Full-Manifests/$BOSH_CLOUD_MANIFEST_NAME.yml"
#
SSL_FOLDER="$DEPLOYMENT_FOLDER/ssl"
SSL_FOLDER_RELATIVE="$DEPLOYMENT_FOLDER_RELATIVE/ssl"
SSL_YML="$SSL_FOLDER/ssl_config.yml"
#
CLOUD_OUTPUTS_CONFIG_FILE="$DEPLOYMENT_FOLDER/outputs.sh"
PASSWORD_CONFIG_FILE="$DEPLOYMENT_FOLDER/passwords.sh"
#
BOSH_SSH_CONFIG_FILE="$DEPLOYMENT_FOLDER/bosh-ssh.sh"
BOSH_CONFIG_FILE="$DEPLOYMENT_FOLDER/bosh-config.sh"

# Set prefix for vars that Bosh will suck in
ENV_PREFIX_NAME='CF_BOSH'
ENV_PREFIX="${ENV_PREFIX_NAME}_"

# Check for required config
[ -d "$MANIFESTS_DIR" ] || FATAL "$MANIFESTS_DIR directory does not exist"
[ -f "$CLOUD_OUTPUTS_CONFIG_FILE" ] || FATAL "Cloud outputs file '$CLOUD_OUTPUTS_CONFIG_FILE' does not exist"
[ -f "$BOSH_LITE_MANIFEST_FILE" ] || FATAL "Bosh lite manifest file '$BOSH_LITE_MANIFEST_FILE' does not exist"
[ -f "$BOSH_FULL_MANIFEST_FILE" ] || FATAL "Bosh manifest file '$BOSH_FULL_MANIFEST_FILE' does not exist"

# Run non-interactively?
[ -n "$INTERACTIVE" ] || BOSH_INTERACTIVE_OPT="--non-interactive"

# Without a TTY (eg within Jenkins) Bosh doesn't seem to output anything when deploying
[ -n "$NO_FORCE_TTY" ] || BOSH_TTY_OPT="--tty"

if [ -z "$NON_AWS_DEPLOYMENT" ]; then
	if [ -n "$AWS_ACCESS_KEY_ID" -a -n "$AWS_SECRET_ACCESS_KEY" ]; then
		INFO 'Attempting to set AWS credentials'
		aws_access_key_id="$AWS_ACCESS_KEY_ID"
		aws_secret_access_key="$AWS_SECRET_ACCESS_KEY"
	else
		INFO 'Attempting to load AWS credentials'
		eval export `parse_aws_credentials | prefix_vars -`
	fi
fi

# Check we have bosh installed
installed_bin bosh

INFO "Loading '$DEPLOYMENT_NAME' config"
eval export `prefix_vars "$CLOUD_OUTPUTS_CONFIG_FILE" "$ENV_PREFIX"`

INFO 'Setting additional variables'
export ${ENV_PREFIX}internal_domain="$INTERNAL_DOMAIN"
eval domain_name="\$${ENV_PREFIX}domain_name"
eval director_dns="\$${ENV_PREFIX}director_dns"
eval deployment_name="\$${ENV_PREFIX}deployment_name"
INTERNAL_SSL_FOLDER="$SSL_FOLDER/$internal_domain"
EXTERNAL_SSL_FOLDER="$SSL_FOLDER/$domain_name"
# Used for Bosh CA cert
EXTERNAL_SSL_FOLDER_RELATIVE="$SSL_FOLDER_RELATIVE/$domain_name"

[ x"$deployment_name" = x"$DEPLOYMENT_NAME" ] || FATAL "Deployment names do not match: $deployment_name != $DEPLOYMENT_NAME"
