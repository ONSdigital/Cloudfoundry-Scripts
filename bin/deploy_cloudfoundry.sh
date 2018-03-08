#!/bin/sh
#
# default vcap password c1oudc0w
#
# https://bosh.io/docs/addons-common.html#misc-users
#
# Parameters:
#
# Variables:
#	DELETE_BOSH_ENV=[true|false]
#	[BOSH_LITE_PRIVATE_IP]
#	UPGRADE_VERSIONS=[true|false]
#	REINTERPOLATE_LITE_STATIC_IPS=[true|false]
#	NO_CREATE_RELEASES=[true|false]
#	REGENERATE_BOSH_CONFIG=[true|false]
#	REUPLOAD_STEMCELL=[true|false]
#	DEBUG=[true|false]
#	RUN_DRY_RUN=[true|false]
#	SKIP_POST_DEPLOY_ERRANDS=[true|false]
#	[POST_DEPLOY_ERRANDS]
#
# Requires:
#	common-bosh.sh
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common-bosh.sh"

# Check if we have any existing Bosh state
if [ -f "$BOSH_LITE_STATE_FILE" ]; then
	if [ x"$DELETE_BOSH_ENV" = x'true' ]; then
		# If we have been asked to delete the Bosh env, we need to retain the state file, otherwise we cannot
		# find the correct VM to delete
		WARN "Not deleting Bootstrap Bosh state file as we need this to delete the Bootstrap Bosh environment"
		WARN "The state file will be deleted after we successfully, delete Bosh"
	elif [ x"$DELETE_BOSH_STATE" = x'true' ]; then
		# If we have manually deleted the Bosh VM, we should delete the state file
		INFO 'Removing Bosh state file'
		rm -f "$BOSH_LITE_STATE_FILE"
	else
		WARN "Existing Bootstrap Bosh state file exists: $BOSH_LITE_STATE_FILE"
	fi
fi

# Do we need to generate the network configuration?
if [ ! -f "$NETWORK_CONFIG_FILE" -o x"$REGENERATE_NETWORKS_CONFIG" = x'true' ]; then
	INFO 'Generating network configuration'
	echo '# Cloudfoundry network configuration' >"$NETWORK_CONFIG_FILE"
	for i in `sed $SED_EXTENDED -ne 's/.*\(\(([^).]*)_cidr\)\).*/\1/gp' "$BOSH_CLOUD_CONFIG_FILE" "$BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE" "$BOSH_LITE_MANIFEST_FILE" | sort -u`; do
		eval cidr="\$${ENV_PREFIX}${i}_cidr"
		"$BASE_DIR/process_cidrs.sh" "$i" "$cidr"
	done >>"$NETWORK_CONFIG_FILE"

	REGENERATE_NETWORKS_CONFIG=true
fi

INFO 'Setting Bosh deployment name'
export ${ENV_PREFIX}bosh_deployment="$DEPLOYMENT_NAME"
INFO 'Loading Bosh SSH config'
export_file_vars "$BOSH_SSH_CONFIG" "$ENV_PREFIX"
INFO 'Loading Bosh network configuration'
export_file_vars "$NETWORK_CONFIG_FILE" "$ENV_PREFIX"

if [ -n "$BOSH_LITE_PRIVATE_IP" ]; then

	grep -Eq "^director_az[1-9]_reserved_ip[0-9]+='$BOSH_LITE_PRIVATE_IP'$" "$NETWORK_CONFIG_FILE" || \
		FATAL "Bosh Lite/Director IP '$BOSH_LITE_PRIVATE_IP' does not exist as a reserved IP within '$NETWORK_CONFIG_FILE'"

	eval "${ENV_PREFIX}bosh_lite_private_ip"="$BOSH_LITE_PRIVATE_IP"
fi


# Do we want to use the existing versions of stemcells/releases?  Individual items can still be overridden if required
# We default to using existing versions unless we have been told not to
if [ -z "$UPGRADE_VERSIONS" -o x"$UPGRADE_VERSIONS" = x'false' ]; then
	if [ -f "$RELEASE_CONFIG_FILE" ]; then
		INFO 'Loading Bosh release versions'
		. "$RELEASE_CONFIG_FILE"
	fi

	if [ -f "$STEMCELL_CONFIG_FILE" ]; then
		INFO 'Loading Bosh stemell versions'
		. "$STEMCELL_CONFIG_FILE"
	fi
fi

# The file is recorded relative to the base directory, but Bosh changes its directory internally, whilst running, to the location of the manifest,
# so we need to make sure the SSH file is an absolute location
#eval bosh_ssh_key_file="\$${ENV_PREFIX}bosh_ssh_key_file"
# We don't want the interpolated Bosh Lite manifest to contain a full path to the SSH file
#findpath "${ENV_PREFIX}bosh_ssh_key_file" "$bosh_ssh_key_file"

# Bosh doesn't seem to be able to handle templating (eg ((variable))) and variables files at the same time, so we need to expand the variables and then use
# the output when we do a bosh create-env/deploy
if [ ! -f "$BOSH_LITE_INTERPOLATED_STATIC_IPS" -o x"$REINTERPOLATE_LITE_STATIC_IPS" = x'true' -o x"$REGENERATE_NETWORKS_CONFIG" = x"true" ]; then
	INFO 'Generating Bosh Lite static IPs'
	"$BOSH_CLI" interpolate \
		--var-errs \
		--vars-env="$ENV_PREFIX_NAME" \
		"$BOSH_LITE_STATIC_IPS_FILE" >"$BOSH_LITE_INTERPOLATED_STATIC_IPS"
fi

# Remove Bosh?
if [ x"$DELETE_BOSH_ENV" = x'true' ]; then
	INFO 'Removing existing Bosh bootstrap environment'
	"$BOSH_CLI" delete-env \
		--tty \
		--state="$BOSH_LITE_STATE_FILE" \
		"$BOSH_LITE_INTERPOLATED_MANIFEST"

	# ... and cleanup any state
	rm -f "$BOSH_LITE_STATE_FILE"
fi

if [ x"$NO_CREATE_RELEASES" != x'true' -o ! -f "$BOSH_LITE_RELEASES" ]; then
	INFO 'Creating releases'

	for _r in `ls releases`; do
		release_name="`echo $_r | sed $SED_EXTENDED -e 's/-release$//g'`"
		release_varname="`echo $release_name | sed $SED_EXTENDED -e 's/-/_/g'`"
		release_filename="$TOP_LEVEL_DIR/releases/$_r/$_r.tgz"
		release_url_value="file://$release_filename"
		release_url_varname="${release_varname}_url"
		release_version_varname="${release_varname}_version"

		if [ ! -f "$release_filename" -o x"$RECREATE_RELEASES" = x'true' ]; then
			INFO ". creating release $_r"
			"$BASE_DIR/bosh-create_release.sh" "$_r" "releases/$_r"

			# We only use the file:// URL for the create-env Bosh. Once that is up, we upload the release
			update_yml_var "$BOSH_LITE_RELEASES" "$release_url_varname" "$release_url_value"

			UPLOAD_RELEASES='true'
		fi
	done
fi


if [ ! -f "$BOSH_LITE_STATE_FILE" ]; then
	CREATE_ACTION='Creating'
	STORE_ACTION='Storing'
else
	CREATE_ACTION='Updating'
	STORE_ACTION='Potentially updating'
fi

INFO "$STORE_ACTION common passwords"
"$BOSH_CLI" interpolate \
	--tty \
	--var-errs \
	--vars-store="$BOSH_COMMON_VARIABLES" \
	"$BOSH_COMMON_VARIABLES_MANIFEST"

INFO 'Interpolating Bosh Lite manifest'
sh -c "'$BOSH_CLI' interpolate \
	--var-errs \
	--vars-env='$ENV_PREFIX_NAME' \
	--vars-file='$BOSH_COMMON_VARIABLES' \
	--vars-file='$BOSH_LITE_RELEASES' \
	--vars-file='$BOSH_LITE_INTERPOLATED_STATIC_IPS' \
	--vars-store='$BOSH_LITE_VARS_STORE' \
	--ops-file='$BOSH_LITE_VARIABLES_OPS_FILE' \
	--ops-file='$BOSH_LITE_CPI_SPECIFIC_OPS_FILE' \
	$BOSH_LITE_PUBLIC_OPS_FILE_OPTIONS \
	$BOSH_LITE_PRIVATE_OPS_FILE_OPTIONS \
	'$BOSH_LITE_MANIFEST_FILE'" >"$BOSH_LITE_INTERPOLATED_MANIFEST"

INFO "$CREATE_ACTION Bosh environment"
"$BOSH_CLI" create-env --tty --state="$BOSH_LITE_STATE_FILE" "$BOSH_LITE_INTERPOLATED_MANIFEST"

INFO "$STORE_ACTION Bosh Director certificate"
"$BOSH_CLI" interpolate --no-color --var-errs --path='/metadata/director_ca' "$BOSH_LITE_INTERPOLATED_MANIFEST" >"$DEPLOYMENT_DIR_RELATIVE/director.crt"

INFO "$STORE_ACTION Bosh Director password"
BOSH_CLIENT_SECRET="`"$BOSH_CLI" interpolate --no-color --var-errs --path='/metadata/director_secret' "$BOSH_LITE_INTERPOLATED_MANIFEST"`"

if [ -n "$BOSH_DIRECTOR_CONFIG" -a ! -f "$BOSH_DIRECTOR_CONFIG" -o x"$REGENERATE_BOSH_CONFIG" = x'true' ] || ! grep -Eq "^BOSH_CLIENT_SECRET='$BOSH_CLIENT_SECRET'" "$BOSH_DIRECTOR_CONFIG"; then
	INFO 'Generating Bosh configuration'
	cat <<EOF >"$BOSH_DIRECTOR_CONFIG"
# Bosh deployment config
BOSH_ENVIRONMENT='$director_dns'
BOSH_DEPLOYMENT='$DEPLOYMENT_NAME'
BOSH_CLIENT_SECRET='$BOSH_CLIENT_SECRET'
BOSH_CLIENT='director'
BOSH_CA_CERT='$DEPLOYMENT_DIR_RELATIVE/director.crt'
EOF
fi

# ... more sanity checking
[ -f "$BOSH_DIRECTOR_CONFIG" ] || FATAL "Bosh configuration file does not exist: '$BOSH_DIRECTOR_CONFIG'"

INFO 'Loading Bosh director config'
export_file_vars "$BOSH_DIRECTOR_CONFIG"

# Convert from relative to an absolute path
findpath BOSH_CA_CERT $BOSH_CA_CERT
export BOSH_CA_CERT

INFO 'Pointing Bosh client at newly deployed Bosh Director'
"$BOSH_CLI" alias-env --tty -e "$BOSH_ENVIRONMENT" "$BOSH_ENVIRONMENT" >&2

INFO 'Attempting to login'
"$BOSH_CLI" log-in --tty >&2

if [ ! -f "$BOSH_FULL_INTERPOLATED_STATIC_IPS" -o x"$REGENERATE_NETWORKS_CONFIG" = x'true' ]; then
	INFO 'Generating Bosh static IPs'
	"$BOSH_CLI" interpolate \
		--no-color \
		--var-errs \
		--vars-env="$ENV_PREFIX_NAME" \
		"$BOSH_FULL_STATIC_IPS_FILE" >"$BOSH_FULL_INTERPOLATED_STATIC_IPS"
fi

INFO 'Generating Availability Variables'
"$BOSH_CLI" interpolate --var-errs --vars-env="$ENV_PREFIX_NAME" --vars-file="$BOSH_FULL_INTERPOLATED_STATIC_IPS" "$BOSH_FULL_AVAILABILITY_VARIABLES" >"$BOSH_FULL_INTERPOLATED_AVAILABILITY"

# Bosh doesn't expand variables from within variables files
INFO 'Generating Cloud Config Variables'
"$BOSH_CLI" interpolate --var-errs --vars-env="$ENV_PREFIX_NAME" "$BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE" >"$BOSH_FULL_INTERPOLATED_CLOUD_CONFIG_VARS"

INFO 'Setting Cloud Config'
"$BOSH_CLI" update-cloud-config --tty --vars-env="$ENV_PREFIX_NAME" --vars-file="$BOSH_FULL_INTERPOLATED_CLOUD_CONFIG_VARS" "$BOSH_CLOUD_CONFIG_FILE"

# Set release versions
for component_version in `sh -c "'$BOSH_CLI' interpolate \
		--no-color \
		--vars-env='$ENV_PREFIX_NAME' \
		--vars-file='$BOSH_COMMON_VARIABLES' \
		--vars-file='$BOSH_FULL_INTERPOLATED_AVAILABILITY' \
		--vars-file='$BOSH_FULL_INTERPOLATED_STATIC_IPS' \
		--vars-file='$BOSH_FULL_INSTANCES_FILE' \
		--vars-store='$BOSH_FULL_VARIABLES_STORE' \
		--ops-file='$BOSH_FULL_VARIABLES_OPS_FILE' \
		--ops-file='$BOSH_FULL_CPI_SPECIFIC_OPS_FILE' \
		$BOSH_FULL_PUBLIC_OPS_FILE_OPTIONS \
		$BOSH_FULL_PRIVATE_OPS_FILE_OPTIONS \
		'$BOSH_FULL_MANIFEST_FILE'" --path /releases | awk '/^  version: \(\([a-z0-9_]+\)\)/{gsub("(\\\(|\\\))",""); print $NF}'`; do

	upper="`echo "$component_version" | tr '[[:lower:]]' '[[:upper:]]'`"

	# eg CF_RELEASE=277
	eval upper_value="\$$upper"

	# eg cf_release=277
	eval lower_value="\$$component_version"

	# Upper case values take priority as these are likely to be set by the person/thing running this script
	if [ -n "$upper_value" ]; then
		INFO "Using $upper_value for $component_version"
		INFO "Overriding ${lower_value:-latest} version and using $upper_value for $component_version"
		version="$upper_value"

	elif [ -n "$lower_value" ] && [ -z "$UPGRADE_VERSIONS" -o x"$UPGRADE_VERSIONS" = x'false' ]; then
		INFO "Using previous version of $lower_value for $component_version"
		version="$lower_value"

	else
		INFO "Using latest for $component_version"
		version='latest'
	fi

	# If v='' then it downloads the latest.  If "$ENV_PREFIX${component_version}_url_suffix"='' then we get a complaint from Bosh:
	# Invalid type '<nil>' for value '<nil>' and variable 'cf_version_url_suffix'. Supported types for interpolation within a string are integers and strings.
	# Exit code 1
	# ?v= or ?version= can both be used
	[ x"$version" = x'latest' ] && url_suffix='?v=' || url_suffix="?v=$version"

	export "$ENV_PREFIX${component_version}_url_suffix"="$url_suffix"

	# Set the version for consumption by Bosh
	export "$ENV_PREFIX$component_version"="$version"
done

# We can't do this before we have the versions set
# XXX
# XXX Unfortunately, running 'interpolate' causes Bosh to upload releases and stemcells and then they get re-uploaded during 'deploy'
# XXX
INFO 'Interpolating Bosh Full manifest'
sh -c "'$BOSH_CLI' interpolate \
	--no-color \
	--var-errs \
	--vars-env='$ENV_PREFIX_NAME' \
	--vars-file='$BOSH_COMMON_VARIABLES' \
	--vars-file='$BOSH_FULL_INTERPOLATED_AVAILABILITY' \
	--vars-file='$BOSH_FULL_INTERPOLATED_STATIC_IPS' \
	--vars-file='$BOSH_FULL_INSTANCES_FILE' \
	--vars-store='$BOSH_FULL_VARIABLES_STORE' \
	$BOSH_FULL_PUBLIC_OPS_FILE_OPTIONS \
	$BOSH_FULL_PRIVATE_OPS_FILE_OPTIONS \
	--ops-file='$BOSH_FULL_VARIABLES_OPS_FILE' \
	--ops-file='$BOSH_FULL_CPI_SPECIFIC_OPS_FILE' \
	'$BOSH_FULL_MANIFEST_FILE'" >"$BOSH_FULL_INTERPOLATED_MANIFEST"

INFO 'Checking if we need to upload any stemcells'
for _s in `"$BOSH_CLI" interpolate --no-color --var-errs --path /stemcells "$BOSH_FULL_INTERPOLATED_MANIFEST" | awk '{if($1 == "os:") print $2}'`; do
	"$BOSH_CLI" stemcells --no-color | awk -v stemcell="$_s" 'BEGIN{ rc=1 }{if($3 == stemcell) rc=0 }END{ exit rc }' || UPLOAD_STEMCELL='true'
done

# Unfortunately, there is no way currently (2017/10/19) for Bosh/Director to automatically upload a stemcell in the same way it does for releases
if [ x"$UPLOAD_STEMCELL" = x'true' -o x"$REUPLOAD_STEMCELL" = x'true' ]; then
	if [ -z "$STEMCELL_URL" ]; then
		WARN 'No STEMCELL_URL provided, finding stemcell details from Bosh Lite deployment'

		STEMCELL_URL="`"$BOSH_CLI" interpolate --no-color --path '/resource_pools/name=bosh_vm/stemcell/url' "$BOSH_LITE_INTERPOLATED_MANIFEST"`"

		[ -z "$STEMCELL_URL" ] && FATAL "Unable to determine Stemcell URL from '$BOSH_LITE_INTERPOLATED_MANIFEST' path '/resource_pools/name=*/stemcell'"
	fi

	if [ -n "$BOSH_STEMCELL_VERSION" ] && echo "$STEMCELL_URL" | grep -Eq '\?v(ersion)?=[0-9]'; then
		WARN 'Stemcell URL already includes version data, so not overriding'

	elif [ -n "$BOSH_STEMCELL_VERSION" ]; then
		URL_EXTENSION="?v=$BOSH_STEMCELL_VERSION"

		UPLOAD_URL="$STEMCELL_URL$URL_EXTENSION"
	else
		UPLOAD_URL="$STEMCELL_URL"

	fi

	INFO "Uploading $UPLOAD_URL to Bosh"
	"$BOSH_CLI" upload-stemcell --tty "$UPLOAD_URL"

fi

if [ x"$UPLOAD_RELEASES" = x'true' ]; then
	for _r in `ls releases`; do
		release_name="`echo $_r | sed $SED_EXTENDED -e 's/-release$//g'`"

		INFO "Checking for release $_r"
		if "$BOSH_CLI" releases | awk -v release="$release_name" 'BEGIN{ rc=1 }{ if($1 == release) rc=0 }END{ exit rc }'; then
			INFO "Checking for release version: $release_name"
			# Bosh prints the versions for a release in decreasing order
			current_version="`"$BOSH_CLI" releases --no-color | awk -v release="$release_name" '{ if($1 == release){ gsub("\\\*","",$2); printf("%s",$2); exit 0 } }'`"
			local_version="`[ -f "releases/$_r/version.txt" ] && cat "releases/$_r/version.txt"`"

			# Check the latest version in the version file
			# Should this include more then 'dev_releases'?
			latest_version="`awk '{ if($1 == "version:" ) print $2 }' "releases/$_r/dev_releases/$release_name/index.yml" | sort | head -n 1`"

			[ x"$local_version" != x"$latest_version" ] && FATAL "Version mismatch version.txt:$local_version != index.yml:$latest_version"

			[ x"$current_version" != x"$local_version" ] && upload_release=1
		else
			INFO "Release does not exist: $release_name"
			upload_release=1
		fi

		if [ -n "$upload_release" ]; then
			[ -f "releases/$_r/$_r.tgz" ] || FATAL "Missing required release $_r archive"

			INFO "Uploading release $_r"
			"$BOSH_CLI" upload-release --tty "releases/$_r/$_r.tgz"
		fi

		unset upload_release
	done
fi

# This is disabled by default as it causes a re-upload of releases/stemcells if their version(s) have been set to 'latest'
if [ x"$RUN_DRY_RUN" = x'true' -o x"$DEBUG" = x'true' ]; then
	INFO 'Checking Bosh deployment dry-run'
	"$BOSH_CLI" deploy --tty --dry-run "$BOSH_FULL_INTERPOLATED_MANIFEST"
fi

INFO 'Setting up CF admin credentials'
SECRET="`"$BOSH_CLI" interpolate --no-color --path '/jobs/name=uaa/properties/uaa/cf_admin/client_secret' "$BOSH_FULL_INTERPOLATED_MANIFEST"`"
PASSWORD="`"$BOSH_CLI" interpolate --no-color --path '/properties/uaa/scim/users/name=cf_admin/password' "$BOSH_FULL_INTERPOLATED_MANIFEST"`"

        cat >"$CF_CREDENTIALS" <<EOF
# Cloudfoundry credentials
CF_ADMIN_USERNAME='cf_admin'
CF_ADMIN_PASSWORD='$PASSWORD'
CF_ADMIN_CLIENT_SECRET='$SECRET'
EOF

# ... finally we get around to running the Bosh/CF deployment
INFO 'Deploying Bosh'
"$BOSH_CLI" deploy --tty "$BOSH_FULL_INTERPOLATED_MANIFEST"

# Do we need to run any errands (eg smoke tests, registrations)
if [ x"$SKIP_POST_DEPLOY_ERRANDS" != x'true' -a -n "$POST_DEPLOY_ERRANDS" ]; then
	INFO 'Running post deployment smoke tests'
	for _e in $POST_DEPLOY_ERRANDS; do
		INFO "Running errand: $_e"
		"$BOSH_CLI" run-errand --tty "$_e"
	done
elif [ x"$SKIP_POST_DEPLOY_ERRANDS" = x'true' ]; then
	INFO 'Skipping run of post deploy errands'

elif [ -z "$POST_DEPLOY_ERRANDS" ]; then
	INFO 'No post deploy errands to run'
fi

# Save stemcell and release versions
for i in stemcell release; do
	INFO "Recording $i(s) versions"
	[ x"$i" = x"release" ] && OUTPUT_FILE="$RELEASE_CONFIG_FILE" || OUTPUT_FILE="$STEMCELL_CONFIG_FILE"

	"$BOSH_CLI" ${i}s | awk -v type="$i" 'BEGIN{
		printf("# Cloudfoundry %ss\n",type)
	}{
		if($1 ~ /^[a-z]/ && ! a[$1]){
			a[$1]++

			gsub("-","_",$1)
			gsub("\\*","",$2)

			printf("%s_version='\''%s'\''\n",$1,$2)
		}
	}' >"$OUTPUT_FILE"
done



# Any post deploy script to run? These are under $POST_DEPLOY_SCRIPTS_DIR/cf
post_deploy_scripts cf

INFO 'Cleaning up any unused releases or stemcells'
"$BOSH_CLI" clean-up --tty --all

INFO 'Bosh VMs'
"$BOSH_CLI" vms

