#!/bin/sh
#
# default vcap password c1oudc0w
#
# https://bosh.io/docs/addons-common.html#misc-users
#
# Set specific stemcell & release versions and match manifest & upload_releases_stemcells.sh

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="$1"
BOSH_FULL_MANIFEST_PREFIX="${2:-Bosh-Template}"
BOSH_CLOUD_MANIFEST_PREFIX="${3:-$BOSH_FULL_MANIFEST_PREFIX-AWS-CloudConfig}"
BOSH_LITE_MANIFEST_NAME="${4:-Bosh-Template}"

MANIFESTS_DIR="${5:-Bosh-Manifests}"
INTERNAL_DOMAIN="${6:-cf.internal}"

. "$BASE_DIR/common.sh"

[ -n "$DEPLOYMENT_NAME" ] || FATAL 'No Bosh deployment name provided'

#
load_outputs "$STACK_OUTPUTS_DIR_RELATIVE" "$ENV_PREFIX"

eval multi_az="\$${ENV_PREFIX}multi_az"

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
