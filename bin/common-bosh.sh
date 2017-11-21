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
CPI_TYPE="${2:-${CPI_TYPE:-AWS}}"
BOSH_FULL_MANIFEST_PREFIX="${3:-${BOSH_FULL_MANIFEST_PREFIX:-Bosh-Template}}"
BOSH_CLOUD_MANIFEST_PREFIX="${4:-${BOSH_CLOUD_MANIFEST_PREFIX:-$BOSH_FULL_MANIFEST_PREFIX-$CPI_TYPE-CloudConfig}}"
# CPI type is appended:
BOSH_LITE_MANIFEST_NAME="${5:-${BOSH_LITE_MANIFEST_NAME:-Bosh-Template}}"
BOSH_PREAMBLE_MANIFEST_NAME="${6:-${BOSH_PREAMBLE_MANIFEST_NAME:-Bosh-Template-preamble}}"
BOSH_STATIC_IPS_PREFIX="${7:-${BOSH_STATIC_IPS_PREFIX:-Bosh-static-ips}}"

MANIFESTS_DIR_RELATIVE="${8:-${MANIFESTS_DIR_RELATIVE:-Bosh-Manifests}}"
INTERNAL_DOMAIN="${9:-${INTERNAL_DOMAIN:-cf.internal}}"


#VARIABLES_BOSH_FULL_OPS_FILENAMES="${VARIABLES_BOSH_FULL_OPS_FILENAMES:-full-variables.yml}"
VARIABLES_BOSH_LITE_OPS_FILENAMES="${VARIABLES_BOSH_LITE_OPS_FILENAMES:-lite-variables.yml}"

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
	# The only differences between MultiAZ and singleAZ +/- HA are the number of availability zones
	BOSH_CLOUD_MANIFEST_NAME="$BOSH_CLOUD_MANIFEST_PREFIX-MultiAZ"
	BOSH_FULL_STATIC_IPS_NAME="$BOSH_STATIC_IPS_PREFIX-MultiAZ"
elif [ x"$single_az_ha" = x"true" ]; then
	BOSH_FULL_MANIFEST_NAME="$BOSH_FULL_MANIFEST_PREFIX-HA"
	# The singleAZ HA CPI manifest is the same as a singleAZ CPI manifest, the differences occur within the main Cloudfoundry manifest
	BOSH_CLOUD_MANIFEST_NAME="$BOSH_CLOUD_MANIFEST_PREFIX"
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

		eval files="\$${j}_BOSH_${upper}_OPS_FILENAMES"

		OLDIFS="$IFS"
		IFS=','

		for file in $files; do
			[ x"$j" != x"PRIVATE" ] && filename="$MANIFESTS_DIR_RELATIVE/Bosh-$i-Manifests/$file" || filename="$OPS_FILES_CONFIG_DIR/$file"

			if [ -n "$filename" ]; then
				[ ! -f "$filename" ] && FATAL "$filename does not exist"

				eval existing="\$${j}_BOSH_${upper}_OPS_FILE_OPTIONS"

				if [ -n "$existing" ]; then
					eval "${j}_BOSH_${upper}_OPS_FILE_OPTIONS"="$existing --ops-file='$filename'"
				else
					eval "${j}_BOSH_${upper}_OPS_FILE_OPTIONS"="--ops-file='$filename'"
				fi
			fi
		done

		IFS="$OLDIFS"
	done
done

#
BOSH_LITE_MANIFEST_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/$BOSH_LITE_MANIFEST_NAME-$CPI_TYPE.yml"
BOSH_LITE_STATIC_IPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/$BOSH_LITE_STATIC_IPS_NAME.yml"

if [ x"$BOSH_PREAMBLE_MANIFEST_NAME" = x"NONE" ]; then
	# We may not always want to run the pre-amble manifest
	 unset BOSH_PREAMBLE_MANIFEST_NAME
	RUN_BOSH_PREAMBLE='false'
	NORUN_BOSH_PREAMBLE='true'
else
	BOSH_PREAMBLE_MANIFEST_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/$BOSH_PREAMBLE_MANIFEST_NAME.yml"
fi

BOSH_FULL_MANIFEST_FILE="$MANIFESTS_DIR/Bosh-Full-Manifests/$BOSH_FULL_MANIFEST_NAME.yml"
BOSH_FULL_MANIFEST_FILE_RELATIVE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/$BOSH_FULL_MANIFEST_NAME.yml"
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
