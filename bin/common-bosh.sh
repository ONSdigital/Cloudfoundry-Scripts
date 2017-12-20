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

# XXX Cleanup
# . skip the arg parsing for these
# . rename
BOSH_FULL_MANIFEST_PREFIX="${3:-${BOSH_FULL_MANIFEST_PREFIX:-Bosh-Template}}"
BOSH_CLOUD_MANIFEST_PREFIX="${4:-${BOSH_CLOUD_MANIFEST_PREFIX:-$BOSH_FULL_MANIFEST_PREFIX-$CPI_TYPE-CloudConfig}}"
# CPI type is appended:
BOSH_LITE_MANIFEST_NAME="${5:-${BOSH_LITE_MANIFEST_NAME:-Bosh-Template}}"
BOSH_STATIC_IPS_PREFIX="${6:-${BOSH_STATIC_IPS_PREFIX:-Bosh-static-ips}}"
BOSH_AVAILABILITY_VARIABLES_PREFIX="${7:-${BOSH_AVAILABILITY_VARIABLES_PREFIX:-Bosh-availability}}"
MANIFESTS_DIR_RELATIVE="${8:-${MANIFESTS_DIR_RELATIVE:-Bosh-Manifests}}"

. "$BASE_DIR/common.sh"

[ -n "$DEPLOYMENT_NAME" ] || FATAL 'No Bosh deployment name provided'

INFO 'Loading AWS outputs'
load_outputs "$STACK_OUTPUTS_DIR" "$ENV_PREFIX"

# Availability type
eval availability="\$${ENV_PREFIX}availability"

# Bosh Lite is not HA
BOSH_LITE_STATIC_IPS_NAME="$BOSH_STATIC_IPS_PREFIX"

# XXX This will be changed when we move to Ops files for changing HA/SingleAZ/MultiAZ bits
if [ x"$availability" = x"MultiAZ" ]; then
	BOSH_FULL_MANIFEST_NAME="$BOSH_FULL_MANIFEST_PREFIX-MultiAZ"
	# The only differences between MultiAZ and singleAZ +/- HA are the number of availability zones
	BOSH_CLOUD_MANIFEST_NAME="$BOSH_CLOUD_MANIFEST_PREFIX-MultiAZ"
	BOSH_CLOUD_AVAILABILITY_VARIABLES_NAME="$BOSH_AVAILABILITY_VARIABLES_PREFIX-$CPI_TYPE-MultiAZ"
	BOSH_FULL_STATIC_IPS_NAME="$BOSH_STATIC_IPS_PREFIX-MultiAZ"
	BOSH_AVAILABILITY_VARIABLES_NAME="$BOSH_AVAILABILITY_VARIABLES_PREFIX-MultiAZ"
elif [ x"$availability" = x"SingleAZ-HA" ]; then
	BOSH_FULL_MANIFEST_NAME="$BOSH_FULL_MANIFEST_PREFIX-HA"
	# The singleAZ HA CPI manifest is the same as a singleAZ CPI manifest, the differences occur within the main Cloudfoundry manifest
	BOSH_CLOUD_MANIFEST_NAME="$BOSH_CLOUD_MANIFEST_PREFIX"
	BOSH_CLOUD_AVAILABILITY_VARIABLES_NAME="$BOSH_AVAILABILITY_VARIABLES_PREFIX-$CPI_TYPE-HA"
	BOSH_FULL_STATIC_IPS_NAME="$BOSH_STATIC_IPS_PREFIX-HA"
	BOSH_AVAILABILITY_VARIABLES_NAME="$BOSH_AVAILABILITY_VARIABLES_PREFIX-HA"
else
	# Assume single AZ and no HA
	BOSH_FULL_MANIFEST_NAME="$BOSH_FULL_MANIFEST_PREFIX"
	BOSH_CLOUD_MANIFEST_NAME="$BOSH_CLOUD_MANIFEST_PREFIX"
	BOSH_CLOUD_AVAILABILITY_VARIABLES_NAME="$BOSH_AVAILABILITY_VARIABLES_PREFIX-$CPI_TYPE-SingleAZ"
	BOSH_FULL_STATIC_IPS_NAME="$BOSH_STATIC_IPS_PREFIX"
	BOSH_AVAILABILITY_VARIABLES_NAME="$BOSH_AVAILABILITY_VARIABLES_PREFIX-SingleAZ"
fi

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

# Common variables
BOSH_COMMON_VARIABLES="$DEPLOYMENT_DIR_RELATIVE/common-variables.yml"
BOSH_COMMON_VARIABLES_MANIFEST="$MANIFESTS_DIR_RELATIVE/Bosh-Common-Manifests/Common-Variables.yml"
BOSH_COMMON_AVAILABILITY_VARIABLES="$MANIFESTS_DIR_RELATIVE/Bosh-Common-Manifests/$BOSH_AVAILABILITY_VARIABLES_NAME.yml"


# Bosh Lite
BOSH_LITE_MANIFEST_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/$BOSH_LITE_MANIFEST_NAME-$CPI_TYPE.yml"
BOSH_LITE_STATIC_IPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/$BOSH_LITE_STATIC_IPS_NAME.yml"
BOSH_LITE_VARIABLES_OPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/Lite-Variables.yml"
#
BOSH_LITE_INTERPOLATED_MANIFEST="$DEPLOYMENT_DIR_RELATIVE/lite-interpolated.yml"
BOSH_LITE_INTERPOLATED_STATIC_IPS="$DEPLOYMENT_DIR_RELATIVE/lite-static-ips.yml"
#
BOSH_LITE_RELEASES="$DEPLOYMENT_DIR_RELATIVE/lite-releases.yml"
BOSH_LITE_STATE_FILE="$DEPLOYMENT_DIR_RELATIVE/$BOSH_LITE_MANIFEST_NAME-$CPI_TYPE-Lite-state.json"
BOSH_LITE_VARIABLES_STORE="$DEPLOYMENT_DIR_RELATIVE/lite-var-store.yml"

# Bosh Full
BOSH_FULL_MANIFEST_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/$BOSH_FULL_MANIFEST_NAME.yml"
BOSH_FULL_STATIC_IPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/$BOSH_FULL_STATIC_IPS_NAME.yml"
BOSH_FULL_VARIABLES_OPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/Full-Variables.yml"
#
BOSH_CLOUD_CONFIG_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/$BOSH_CLOUD_MANIFEST_NAME.yml"
BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/$BOSH_CLOUD_AVAILABILITY_VARIABLES_NAME.yml"
BOSH_CLOUD_VARIABLES_AVAILABILITY_INTERPOLATED="$DEPLOYMENT_DIR_RELATIVE/cloud-config-variables-interpolated.yml"
#
BOSH_FULL_INTERPOLATED_MANIFEST="$DEPLOYMENT_DIR_RELATIVE/full-interpolated.yml"
BOSH_FULL_INTERPOLATED_STATIC_IPS="$DEPLOYMENT_DIR_RELATIVE/full-static-ips.yml"
#
# BOSH_FULL_VARIABLES_STORE -> relocated to common.sh for use by setup-cf_admin.sh

# Check for required config
[ -d "$MANIFESTS_DIR" ] || FATAL "$MANIFESTS_DIR directory does not exist"
[ -d "$STACK_OUTPUTS_DIR" ] || FATAL "Cloud outputs directory '$STACK_OUTPUTS_DIR' does not exist"

#
[ -f "$BOSH_COMMON_AVAILABILITY_VARIABLES" ] || FATAL "Bosh availability variables file '$BOSH_COMMON_AVAILABILITY_VARIABLES' does not exist"

#
[ -f "$BOSH_LITE_MANIFEST_FILE" ] || FATAL "Bosh Lite manifest file '$BOSH_LITE_MANIFEST_FILE' does not exist"
[ -f "$BOSH_LITE_STATIC_IPS_FILE" ] || FATAL "Bosh Lite static IPs file '$BOSH_LITE_STATIC_IPS_FILE' does not exist"

#
[ -f "$BOSH_FULL_MANIFEST_FILE" ] || FATAL "Bosh manifest file '$BOSH_FULL_MANIFEST_FILE' does not exist"
[ -f "$BOSH_FULL_STATIC_IPS_FILE" ] || FATAL "Bosh static IPs file '$BOSH_FULL_STATIC_IPS_FILE' does not exist"

#
[ -f "$BOSH_CLOUD_CONFIG_FILE" ] || FATAL "Bosh CPI file '$BOSH_CLOUD_CONFIG_FILE' does not exist"
[ -f "$BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE" ] || FATAL "Bosh CPI specific variables file '$BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE' does not exist"

# Run non-interactively?
[ x"$INTERACTIVE" = x'true' ] || export BOSH_NON_INTERACTIVE='true'

# Without a TTY (eg within Jenkins) Bosh doesn't seem to output anything when deploying
[ -n "$NO_FORCE_TTY" ] || BOSH_TTY_OPT="--tty"

# Check we have bosh installed
installed_bin bosh

INFO 'Setting additional variables'
eval domain_name="\$${ENV_PREFIX}domain_name"
eval director_dns="\$${ENV_PREFIX}director_dns"
eval deployment_name="\$${ENV_PREFIX}deployment_name"

[ x"$deployment_name" = x"$DEPLOYMENT_NAME" ] || FATAL "Deployment names do not match: $deployment_name != $DEPLOYMENT_NAME"
