#
# default vcap password c1oudc0w
#
# https://bosh.io/docs/addons-common.html#misc-users
#
# Set specific stemcell & release versions and match manifest & upload_releases_stemcells.sh
#
# Parameters:
#	[Deployment Name]
#	[CPI Type]
#
# Variables:
#	[DEPLOYMENT_NAME]
#	[CPI_TYPE]
#
# Requires:
#	common.sh

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
CPI_TYPE="${2:-${CPI_TYPE:-AWS}}"

. "$BASE_DIR/common.sh"

[ -n "$DEPLOYMENT_NAME" ] || FATAL 'No Bosh deployment name provided'

# Check for required config
[ -d "$STACK_OUTPUTS_DIR" ] || FATAL "Cloud outputs directory '$STACK_OUTPUTS_DIR' does not exist"

INFO 'Loading AWS outputs'
load_outputs "$STACK_OUTPUTS_DIR" "$ENV_PREFIX"

# Force Bosh to be non-interactive
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
for i in Director CF; do
	if [ "${i}" == Director ] && [ "$CPI_TYPE" == AWS ]; then
		break
	fi
	[ -d "$MANIFESTS_DIR_RELATIVE/Bosh-$i-Manifests/$CPI_TYPE" ] || FATAL "Unknown CPI type: $CPI_TYPE"

	for j in PUBLIC PRIVATE; do
		upper="`echo $i | tr '[[:lower:]]' '[[:upper:]]'`"

		eval files="\$${j}_BOSH_${upper}_OPS_FILENAMES"

		OLDIFS="$IFS"
		IFS=','

		for file in $files; do
			[ x"$j" != x"PRIVATE" ] && filename="$MANIFESTS_DIR_RELATIVE/Bosh-$i-Manifests/Ops/$file" || filename="$OPS_FILES_CONFIG_DIR/$file"

			if [ -n "$filename" ]; then
				[ ! -f "$filename" ] && FATAL "$filename does not exist"

				eval existing="\$${j}_BOSH_${upper}_OPS_FILE_OPTIONS"

				INFO "Adding ops-file: $filename"
				if [ -n "$existing" ]; then
					eval "BOSH_${upper}_${j}_OPS_FILE_OPTIONS"="$existing --ops-file='$filename'"
				else
					eval "BOSH_${upper}_${j}_OPS_FILE_OPTIONS"="--ops-file='$filename'"
				fi
			fi
		done

		IFS="$OLDIFS"
	done
done

# Common interpolated variables
BOSH_COMMON_VARIABLES="$DEPLOYMENT_DIR_RELATIVE/common-variables.yml"

# Director interpolated variables
BOSH_DIRECTOR_INTERPOLATED_MANIFEST="$DEPLOYMENT_DIR_RELATIVE/director-interpolated.yml"
BOSH_DIRECTOR_INTERPOLATED_STATIC_IPS="$DEPLOYMENT_DIR_RELATIVE/director-static-ips.yml"

#
BOSH_DIRECTOR_STATE_FILE="$DEPLOYMENT_DIR_RELATIVE/bosh-director-$CPI_TYPE-state.json"
BOSH_DIRECTOR_RELEASES="$DEPLOYMENT_DIR_RELATIVE/director-releases.yml"
BOSH_DIRECTOR_VARS_STORE="$DEPLOYMENT_DIR_RELATIVE/director-var-store.yml"

# CF interpolated variables
BOSH_CF_INTERPOLATED_CLOUD_CONFIG_VARS="$DEPLOYMENT_DIR_RELATIVE/cloud-config-variables-interpolated.yml"
BOSH_CF_INTERPOLATED_MANIFEST="$DEPLOYMENT_DIR_RELATIVE/cf-interpolated.yml"
BOSH_CF_INTERPOLATED_STATIC_IPS="$DEPLOYMENT_DIR_RELATIVE/cf-static-ips.yml"
BOSH_CF_INTERPOLATED_AVAILABILITY="$DEPLOYMENT_DIR_RELATIVE/cf-variables-interpolated.yml"

# Common Manifests
BOSH_COMMON_VARIABLES_MANIFEST="$MANIFESTS_DIR_RELATIVE/Bosh-Common-Manifests/Common-Variables.yml"

# Bosh Director Manifests
BOSH_DIRECTOR_MANIFEST_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Director-Manifests/bosh-deployment/bosh.yml"
BOSH_DIRECTOR_CPI_SPECIFIC_OPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Director-Manifests/$CPI_TYPE/Adjustments.yml"
BOSH_DIRECTOR_STATIC_IPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-Director-Manifests/Static-IPs/Bosh-Static-IPs.yml"
BOSH_DEPLOYMENT_DIR="${MANIFESTS_DIR_RELATIVE}/Bosh-Director-Manifests/bosh-deployment"

# Bosh Cloud Config Manifests
BOSH_CLOUD_CONFIG_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-CF-Manifests/$CPI_TYPE/Bosh-CloudConfig.yml"
BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-CF-Manifests/$CPI_TYPE/Availability/Bosh-Availability-$availability.yml"

if [ $CPI_TYPE == "AWS" ]; then
	BOSH_CLOUD_CONFIG_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-CF-Manifests/iaas-support/aws/cloud-config.yml"
	if [ "${availability}" = MultiAZ ]; then
		availability_type=multi
	else
		availability_type=single
	fi
	BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-CF-Manifests/iaas-support/$(echo "${CPI_TYPE}" | awk '{print tolower($0)}')/availability/${availability_type}-az.yml"
fi

# Bosh CF Manifests
BOSH_CF_MANIFEST_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-CF-Manifests/cf-deployment/cf-deployment.yml"
BOSH_CF_CPI_SPECIFIC_OPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-CF-Manifests/$CPI_TYPE/Adjustments.yml"
BOSH_CF_STATIC_IPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-CF-Manifests/Static-IPs/Bosh-Static-IPs-$availability.yml"
BOSH_CF_VARIABLES_OPS_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-CF-Manifests/Common-Variables.yml"
BOSH_CF_AVAILABILITY_VARIABLES="$MANIFESTS_DIR_RELATIVE/Bosh-CF-Manifests/Availability/Bosh-Availability-$availability.yml"
BOSH_CF_DEPLOYMENT_DIR="${MANIFESTS_DIR_RELATIVE}/Bosh-CF-Manifests/cf-deployment"
# BOSH_CF_VARIABLES_STORE -> relocated to common.sh for use by setup-cf_admin.sh

# Bosh RabbitMQ Manifests

BOSH_RMQ_MANIFEST_FILE="$MANIFESTS_DIR_RELATIVE/Bosh-CF-Manifests/bosh-rmq-broker/manifest.yml"
BOSH_RMQ_DEPLOYMENT_DIR="${MANIFESTS_DIR_RELATIVE}/Bosh-CF-Manifests/bosh-rmq-broker"
BOSH_RMQ_INTERPOLATED_MANIFEST="$DEPLOYMENT_DIR_RELATIVE/rmq-interpolated.yml"
BOSH_RMQ_VARIABLES_STORE="$DEPLOYMENT_DIR_RELATIVE/rmq-var-store.yml"


for _f in BOSH_COMMON_VARIABLES_MANIFEST \
	BOSH_DIRECTOR_STATIC_IPS_FILE BOSH_DIRECTOR_CPI_SPECIFIC_OPS_FILE \
	BOSH_CLOUD_CONFIG_FILE BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE \
	BOSH_CF_MANIFEST_FILE BOSH_CF_STATIC_IPS_FILE BOSH_CF_VARIABLES_OPS_FILE BOSH_CF_AVAILABILITY_VARIABLES BOSH_CF_INSTANCES_FILE; do
	if [ "$_f" == BOSH_DIRECTOR_CPI_SPECIFIC_OPS_FILE ] && [ "$CPI_TYPE" == AWS ]; then
		break
	fi

	eval file="\$$_f"
	englishified="`echo $_f | englishify | sed $SED_EXTENDED -e 's/-Ips/-IPs/g'`"

	[ -n "$file" ] || FATAL "$_f has not been set"

	[ -f "$file" ] || FATAL "$englishified '$file' does not exist"

	unset file englishified
done

# Check we have bosh installed
installed_bin bosh
