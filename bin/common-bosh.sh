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

. "$BASE_DIR/common.sh"

[ -n "$DEPLOYMENT_NAME" ] || FATAL 'No Bosh deployment name provided'

INFO 'Loading AWS outputs'
load_outputs "$STACK_OUTPUTS_DIR" "$ENV_PREFIX"

# Tweak Bosh settings
export BOSH_NON_INTERACTIVE='true'

INFO 'Setting additional variables'
eval domain_name="\$${ENV_PREFIX}domain_name"
eval director_dns="\$${ENV_PREFIX}director_dns"
eval deployment_name="\$${ENV_PREFIX}deployment_name"
eval availability="\$${ENV_PREFIX}availability"

[ -z "$availability" ] && FATAL 'Availability type has not been set'
[ x"$deployment_name" = x"$DEPLOYMENT_NAME" ] || FATAL "Deployment names do not match: $deployment_name != $DEPLOYMENT_NAME"

MANIFESTS_DIR_RELATIVE="Bosh-Manifests"
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

# Common interpolated variables
BOSH_COMMON_VARIABLES="$DEPLOYMENT_DIR_RELATIVE/common-variables.yml"

# Lite interpolated variables
BOSH_LITE_INTERPOLATED_MANIFEST="$DEPLOYMENT_DIR_RELATIVE/lite-interpolated.yml"
BOSH_LITE_INTERPOLATED_STATIC_IPS="$DEPLOYMENT_DIR_RELATIVE/lite-static-ips.yml"

#
BOSH_LITE_STATE_FILE="$DEPLOYMENT_DIR_RELATIVE/bosh-lite-$CPI_TYPE-state.json"
BOSH_LITE_RELEASES="$DEPLOYMENT_DIR_RELATIVE/lite-releases.yml"
BOSH_LITE_VARS_STORE="$DEPLOYMENT_DIR_RELATIVE/lite-var-store.yml"

# Full interpolated variables
BOSH_FULL_INTERPOLATED_CLOUD_CONFIG_VARS="$DEPLOYMENT_DIR_RELATIVE/cloud-config-variables-interpolated.yml"
BOSH_FULL_INTERPOLATED_MANIFEST="$DEPLOYMENT_DIR_RELATIVE/full-interpolated.yml"
BOSH_FULL_INTERPOLATED_STATIC_IPS="$DEPLOYMENT_DIR_RELATIVE/full-static-ips.yml"
BOSH_FULL_INTERPOLATED_AVAILABILITY="$DEPLOYMENT_DIR_RELATIVE/full-variables-interpolated.yml"

# Common Manifests
BOSH_COMMON_VARIABLES_MANIFEST="$MANIFESTS_DIR_RELATIVE/Bosh-Common-Manifests/Common-Variables.yml"

# Bosh Lite Manifests
BOSH_LITE_MANIFEST_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/Bosh-Template-$CPI_TYPE.yml"
BOSH_LITE_STATIC_IPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/Bosh-Static-IPs.yml"
BOSH_LITE_VARIABLES_OPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/Lite-Variables.yml"

# Bosh Full Manifests
BOSH_FULL_MANIFEST_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/Bosh-Template.yml"
BOSH_FULL_STATIC_IPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/Bosh-Static-IPs-$availability.yml"
BOSH_FULL_VARIABLES_OPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/Full-Variables.yml"
BOSH_FULL_AVAILABILITY_VARIABLES="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/Bosh-Availability-$availability.yml"

# Bosh Cloud Config Manifests
BOSH_CLOUD_CONFIG_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/Bosh-Template-$CPI_TYPE-CloudConfig.yml"
BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/Bosh-Availability-$CPI_TYPE-$availability.yml"
#
#
# BOSH_FULL_VARIABLES_STORE -> relocated to common.sh for use by setup-cf_admin.sh

# This needs simplifying
# Check for required config
[ -d "$MANIFESTS_DIR" ] || FATAL "$MANIFESTS_DIR directory does not exist"
[ -d "$STACK_OUTPUTS_DIR" ] || FATAL "Cloud outputs directory '$STACK_OUTPUTS_DIR' does not exist"

for _f in BOSH_COMMON_VARIABLES_MANIFEST \
	BOSH_LITE_MANIFEST_FILE BOSH_LITE_STATIC_IPS_FILE \
	BOSH_CLOUD_CONFIG_FILE BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE \
	BOSH_FULL_MANIFEST_FILE BOSH_FULL_STATIC_IPS_FILE BOSH_FULL_AVAILABILITY_VARIABLES; do

	eval file="\$$_f"
	englishified="`echo $_f | englishify | sed $SED_EXTENDED -e 's/-Ips/-IPs/g'`"

	[ -n "$file" ] || FATAL "$_f has not been set"
	
	[ -f "$file" ] || FATAL "$englishified '$file' does not exist"

	unset file englishified
done

#[ -f "$BOSH_COMMON_VARIABLES_MANIFEST" ] || FATAL "Common Bosh variables manifest file '$BOSH_COMMON_VARIABLES_MANIFEST' does not exist"
#
#[ -f "$BOSH_COMMON_AVAILABILITY_VARIABLES" ] || FATAL "Bosh availability variables file '$BOSH_COMMON_AVAILABILITY_VARIABLES' does not exist"

#
#[ -f "$BOSH_LITE_MANIFEST_FILE" ] || FATAL "Bosh Lite manifest file '$BOSH_LITE_MANIFEST_FILE' does not exist"
#[ -f "$BOSH_LITE_STATIC_IPS_FILE" ] || FATAL "Bosh Lite static IPs file '$BOSH_LITE_STATIC_IPS_FILE' does not exist"

#
#[ -f "$BOSH_FULL_MANIFEST_FILE" ] || FATAL "Bosh manifest file '$BOSH_FULL_MANIFEST_FILE' does not exist"
#[ -f "$BOSH_FULL_STATIC_IPS_FILE" ] || FATAL "Bosh static IPs file '$BOSH_FULL_STATIC_IPS_FILE' does not exist"

#
#[ -f "$BOSH_CLOUD_CONFIG_FILE" ] || FATAL "Bosh CPI file '$BOSH_CLOUD_CONFIG_FILE' does not exist"
#[ -f "$BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE" ] || FATAL "Bosh CPI specific variables file '$BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE' does not exist"


# Check we have bosh installed
installed_bin bosh


