#!/bin/sh
#
# default vcap password c1oudc0w
#
# https://bosh.io/docs/addons-common.html#misc-users
#
# Set specific stemcell & release versions and match manifest & upload_releases_stemcells.sh

set -e

BASE_DIR="`dirname \"$0\"`"

CPI_TYPE="${CPI_TYPE:-AWS}"

DEPLOYMENT_NAME="$1"
BOSH_FULL_MANIFEST_PREFIX="${2:-Bosh-Template}"
BOSH_CLOUD_MANIFEST_PREFIX="${3:-$BOSH_FULL_MANIFEST_PREFIX-$CPI_TYPE-CloudConfig}"
BOSH_LITE_MANIFEST_NAME="${4:-Bosh-Template-$CPI_TYPE}"
BOSH_PREAMBLE_MANIFEST_NAME="${5:-Bosh-Template-preamble}"
BOSH_STATIC_IPS_PREFIX="${6:-Bosh-static-ips}"

MANIFESTS_DIR_RELATIVE="${7:-Bosh-Manifests}"
INTERNAL_DOMAIN="${8:-cf.internal}"

. "$BASE_DIR/common.sh"

[ -n "$DEPLOYMENT_NAME" ] || FATAL 'No Bosh deployment name provided'

#
load_outputs "$STACK_OUTPUTS_DIR" "$ENV_PREFIX"

# MultiAZ assumes HA
eval multi_az="\$${ENV_PREFIX}multi_az"
# SingleAZ with HA
eval single_az_ha="\$${ENV_PREFIX}single_az_ha"

# Bosh Lite is not HA
BOSH_LITE_STATIC_IPS_NAME="$BOSH_STATIC_IPS_PREFIX"

if [ x"$multi_az" = x"true" ]; then
	BOSH_FULL_MANIFEST_NAME="$BOSH_FULL_MANIFEST_PREFIX-MultiAZ"
	BOSH_CLOUD_MANIFEST_NAME="$BOSH_CLOUD_MANIFEST_PREFIX-MultiAZ"
	BOSH_FULL_STATIC_IPS_NAME="$BOSH_STATIC_IPS_PREFIX-MultiAZ"
elif [ x"$single_az_ha" = x"true" ]; then
	BOSH_FULL_MANIFEST_NAME="$BOSH_FULL_MANIFEST_PREFIX-HA"
	BOSH_CLOUD_MANIFEST_NAME="$BOSH_CLOUD_MANIFEST_PREFIX-HA"
	BOSH_FULL_STATIC_IPS_NAME="$BOSH_STATIC_IPS_PREFIX-HA"
else
	# Assume single AZ and no HA
	BOSH_FULL_MANIFEST_NAME="$BOSH_FULL_MANIFEST_PREFIX"
	BOSH_CLOUD_MANIFEST_NAME="$BOSH_CLOUD_MANIFEST_PREFIX"
	BOSH_FULL_STATIC_IPS_NAME="$BOSH_STATIC_IPS_PREFIX"
fi

#
BOSH_LITE_STATE_FILE="$DEPLOYMENT_DIR_RELATIVE/$BOSH_LITE_MANIFEST_NAME-Lite-state.json"

# Expand manifests dir to full path
findpath MANIFESTS_DIR "$MANIFESTS_DIR_RELATIVE"

# Private, per deployment, ops files, eq for installation specific operartions
# Publically available ops files, eg adjustments for VMware
for i in Lite Full; do
	for j in PUBLIC PRIVATE; do
		upper="`echo $i | tr '[[:lower:]]' '[[:upper:]]'`"

		eval file_name="\$${j}_BOSH_${upper}_OPS_FILENAME"

		[ x"$j" = x"PUBLIC" ] && file="$MANIFESTS_DIR/Bosh-$i-Manifests/$file_name" || file="$OPS_FILES_CONFIG_DIR/$file_name"

		if [ -n "$file_name" ]; then
			[ ! -f "$file" ] && FATAL "$file does not exist"

			eval "${j}_BOSH_${upper}_OPS_FILE"="'$file'"
		fi
	done
done

#
BOSH_LITE_MANIFEST_FILE="$MANIFESTS_DIR/Bosh-Lite-Manifests/$BOSH_LITE_MANIFEST_NAME.yml"
BOSH_LITE_STATIC_IPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/$BOSH_LITE_STATIC_IPS_NAME.yml"
BOSH_PREAMBLE_MANIFEST_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/$BOSH_PREAMBLE_MANIFEST_NAME.yml"
BOSH_FULL_MANIFEST_FILE="$MANIFESTS_DIR/Bosh-Full-Manifests/$BOSH_FULL_MANIFEST_NAME.yml"
BOSH_FULL_CLOUD_CONFIG_FILE="$MANIFESTS_DIR/Bosh-Full-Manifests/$BOSH_CLOUD_MANIFEST_NAME.yml"
BOSH_FULL_STATIC_IPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/$BOSH_FULL_STATIC_IPS_NAME.yml"

# Check for required config
[ -d "$MANIFESTS_DIR" ] || FATAL "$MANIFESTS_DIR directory does not exist"
[ -d "$STACK_OUTPUTS_DIR" ] || FATAL "Cloud outputs directory '$STACK_OUTPUTS_DIR' does not exist"
#
[ -f "$BOSH_LITE_MANIFEST_FILE" ] || FATAL "Bosh Lite manifest file '$BOSH_LITE_MANIFEST_FILE' does not exist"
[ -f "$BOSH_LITE_STATIC_IPS_FILE" ] || FATAL "Bosh Lite static IPs file '$BOSH_LITE_STATIC_IPS_FILE' does not exist"
#
[ -f "$BOSH_PREAMBLE_MANIFEST_FILE" ] || FATAL "Bosh manifest file '$BOSH_PREAMBLE_MANIFEST_FILE' does not exist"
#
[ -f "$BOSH_FULL_MANIFEST_FILE" ] || FATAL "Bosh manifest file '$BOSH_FULL_MANIFEST_FILE' does not exist"
[ -f "$BOSH_FULL_STATIC_IPS_FILE" ] || FATAL "Bosh static IPs file '$BOSH_FULL_STATIC_IPS_FILE' does not exist"

# Run non-interactively?
[ x"$INTERACTIVE" = x'true' ] || export BOSH_NON_INTERACTIVE='true'

# Without a TTY (eg within Jenkins) Bosh doesn't seem to output anything when deploying
[ -n "$NO_FORCE_TTY" ] || BOSH_TTY_OPT="--tty"

# Check we have bosh installed
installed_bin bosh

SSL_DIR="$DEPLOYMENT_DIR/ssl"
SSL_DIR_RELATIVE="$DEPLOYMENT_DIR_RELATIVE/ssl"
SSL_YML="$SSL_DIR/ssl_config.yml"
SSL_YML_RELATIVE="$SSL_DIR_RELATIVE/ssl_config.yml"

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
