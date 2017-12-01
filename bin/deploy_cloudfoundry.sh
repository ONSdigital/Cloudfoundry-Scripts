#!/bin/sh
#
# default vcap password c1oudc0w
#
# https://bosh.io/docs/addons-common.html#misc-users
#
# Set specific stemcell & release versions and match manifest & upload_releases_stemcells.sh

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common-bosh.sh"

# Check if we have any existing Bosh state
if [ -f "$BOSH_LITE_STATE_FILE" ]; then
	if [ x"$DELETE_BOSH_ENV" = x"true" ]; then
		# If we have been asked to delete the Bosh env, we need to retain the state file, otherwise we cannot
		# find the correct VM to delete
		WARN "Not deleting Bootstrap Bosh state file as we need this to delete the Bootstrap Bosh environment"
		WARN "The state file will be deleted after we successfully, delete Bosh"
	elif [ x"$DELETE_BOSH_STATE" = x"true" ]; then
		# If we have manually deleted the Bosh VM, we should delete the state file
		INFO 'Removing Bosh state file'
		rm -f "$BOSH_LITE_STATE_FILE"
	else
		WARN "Existing Bootstrap Bosh state file exists: $BOSH_LITE_STATE_FILE"
	fi
fi

# Do we need to generate the network configuration?
if [ ! -f "$NETWORK_CONFIG_FILE" -o x"$REGENERATE_NETWORKS_CONFIG" = x"true" ]; then
	INFO 'Generating network configuration'
	echo '# Cloudfoundry network configuration' >"$NETWORK_CONFIG_FILE"
	for i in `sed $SED_EXTENDED -ne 's/.*\(\(([^).]*)_cidr\)\).*/\1/gp' "$BOSH_FULL_CLOUD_CONFIG_FILE" "$BOSH_LITE_MANIFEST_FILE" | sort -u`; do
		eval cidr="\$${ENV_PREFIX}${i}_cidr"
		"$BASE_DIR/process_cidrs.sh" "$i" "$cidr"
	done >>"$NETWORK_CONFIG_FILE"
fi

INFO 'Setting Bosh deployment name'
export ${ENV_PREFIX}bosh_deployment="$DEPLOYMENT_NAME"
INFO 'Loading Bosh SSH config'
export_file_vars "$BOSH_SSH_CONFIG" "$ENV_PREFIX"
INFO 'Loading Bosh network configuration'
export_file_vars "$NETWORK_CONFIG_FILE" "$ENV_PREFIX"

# Do we want to use the existing versions of stemcells/releases?  Individual items can still be overridden if required
# We default to using existing versions unless we have been told not to
if [ x"$USE_EXISTING_VERSIONS" != x"false" ]; then
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
eval bosh_ssh_key_file="\$${ENV_PREFIX}bosh_ssh_key_file"
findpath "${ENV_PREFIX}bosh_ssh_key_file" "$bosh_ssh_key_file"

# Bosh doesn't seem to be able to handle templating (eg ((variable))) and variables files at the same time, so we need to expand the variables and then use
# the output when we do a bosh create-env/deploy
if [ ! -f "$LITE_STATIC_IPS_YML" -o "$REINTERPOLATE_LITE_STATIC_IPS" = x"true" ]; then
	INFO 'Generating Bosh Lite static IPs'
	"$BOSH_CLI" interpolate \
		--vars-env="$ENV_PREFIX_NAME" \
		--vars-file="$BOSH_LITE_STATIC_IPS_FILE" \
		"$BOSH_LITE_STATIC_IPS_FILE" >"$BOSH_LITE_STATIC_IPS_YML"
fi

# Remove Bosh?
if [ x"$DELETE_BOSH_ENV" = x"true" ]; then
	INFO 'Removing existing Bosh bootstrap environment'
	sh -c "'$BOSH_CLI' delete-env \
			--tty \
			 --non-interactive \
			$BOSH_LITE_PUBLIC_OPS_FILE_OPTIONS \
			$BOSH_LITE_PRIVATE_OPS_FILE_OPTIONS \
			--ops-file='$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/lite-variables.yml' \
			--state='$BOSH_LITE_STATE_FILE' \
			--vars-env='$ENV_PREFIX_NAME' \
			--vars-file='$BOSH_LITE_STATIC_IPS_YML' \
			--vars-store='$DEPLOYMENT_DIR_RELATIVE/lite-var-store.yml' \
			'$BOSH_LITE_MANIFEST_FILE'"

	# ... and cleanup any state
	rm -f "$BOSH_LITE_STATE_FILE"
fi

# Allow running of a custom script that can do other things (eg create a local release) - it'd be nice if this could be made more intelligent
if [ x"$NORUN_PREDEPLOY" != x"true" -a -f "$TOP_LEVEL_DIR/pre_deploy.sh" ]; then
	[ -x "$TOP_LEVEL_DIR/pre_deploy.sh" ] || chmod +x "$TOP_LEVEL_DIR/pre_deploy.sh"

	"$TOP_LEVEL_DIR/pre_deploy.sh"
fi


if [ -n "$DEBUG" ]; then
	INFO 'Interpolated Bosh lite manifest'
	sh -c "'$BOSH_CLI' interpolate \
			--tty \
			--var-errs \
			$BOSH_LITE_PUBLIC_OPS_FILE_OPTIONS \
			$BOSH_LITE_PRIVATE_OPS_FILE_OPTIONS \
			--ops-file='$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/lite-variables.yml' \
			--vars-env='$ENV_PREFIX_NAME' \
			--vars-file='$BOSH_LITE_STATIC_IPS_YML' \
			--vars-store='$DEPLOYMENT_DIR_RELATIVE/lite-var-store.yml' \
			'$BOSH_LITE_MANIFEST_FILE'"
fi

if [ ! -f "$BOSH_LITE_STATE_FILE" ]; then
	CREATE_ACTION='Creating'
	STORE_ACTION='Storing'

	# (Re)upload the stemcell
	REUPLOAD_STEMCELL='true'
else
	CREATE_ACTION='Updating'
	STORE_ACTION='Potentially updating'
fi

INFO "$CREATE_ACTION Bosh environment"
sh -c "'$BOSH_CLI' create-env \
		--tty \
		--non-interactive \
		$BOSH_LITE_PUBLIC_OPS_FILE_OPTIONS \
		$BOSH_LITE_PRIVATE_OPS_FILE_OPTIONS \
		--ops-file='$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/lite-variables.yml' \
		--state='$BOSH_LITE_STATE_FILE' \
		--vars-env='$ENV_PREFIX_NAME' \
		--vars-file='$BOSH_LITE_STATIC_IPS_YML' \
		--vars-store='$DEPLOYMENT_DIR_RELATIVE/lite-var-store.yml' \
		'$BOSH_LITE_MANIFEST_FILE'"


INFO "$STORE_ACTION Bosh Director certificate"
sh -c "'$BOSH_CLI' interpolate \
		--no-color \
		$BOSH_LITE_PUBLIC_OPS_FILE_OPTIONS \
		$BOSH_LITE_PRIVATE_OPS_FILE_OPTIONS \
		--ops-file='$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/lite-variables.yml' \
		--vars-env='$ENV_PREFIX_NAME' \
		--vars-file='$BOSH_LITE_STATIC_IPS_YML' \
		--vars-store='$DEPLOYMENT_DIR_RELATIVE/lite-var-store.yml' \
		--path='/metadata/director_ca' \
		$BOSH_LITE_MANIFEST_FILE" >"$DEPLOYMENT_DIR_RELATIVE/director.crt"


INFO "$UPDATE_ACTION Bosh Director password"
BOSH_CLIENT_SECRET="`"$BOSH_CLI" interpolate \
	--no-color \
	--ops-file="$MANIFESTS_DIR_RELATIVE/Bosh-Lite-Manifests/lite-variables.yml" \
	--vars-env=$ENV_PREFIX_NAME \
	--vars-file=$BOSH_LITE_STATIC_IPS_YML \
	--vars-store="$DEPLOYMENT_DIR_RELATIVE/lite-var-store.yml" \
	--path '/metadata/director_secret' \
	"$BOSH_LITE_MANIFEST_FILE"`" || rc=$?

# Do not keep any state file if things fail
if [ 0$rc -ne 0 ]; then
	[ -n "$KEEP_BOSH_STATE" ] || rm -f "$BOSH_LITE_STATE_FILE"

	FATAL 'Bosh lite deployment failed'
fi


if [ -n "$BOSH_DIRECTOR_CONFIG" -a ! -f "$BOSH_DIRECTOR_CONFIG" -o x"$REGENERATE_BOSH_CONFIG" = x"true" ] || ! grep -Eq "^BOSH_CLIENT_SECRET='$BOSH_CLIENT_SECRET'" "$BOSH_DIRECTOR_CONFIG"; then
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

if [ ! -f "$FULL_STATIC_IPS_YML" -o "$REINTERPOLATE_FULL_STATIC_IPS" = x"true" ]; then
	INFO 'Generating Bosh static IPs'
	"$BOSH_CLI" interpolate \
		--no-color \
		--vars-env="$ENV_PREFIX_NAME" \
		--vars-file="$BOSH_FULL_STATIC_IPS_FILE" \
		"$BOSH_FULL_STATIC_IPS_FILE" >"$BOSH_FULL_STATIC_IPS_YML"
fi

INFO 'Setting CloudConfig'
"$BOSH_CLI" update-cloud-config --tty --vars-env="$ENV_PREFIX_NAME" "$BOSH_FULL_CLOUD_CONFIG_FILE"

# Set release versions
#for component_version in `NO_YML=1 NO_VAR_ERRS=1 bosh_full interpolate "$BOSH_FULL_MANIFEST_FILE" --path /releases | awk '/^  version: \(\([a-z0-9_]+\)\)/{gsub("(\\\(|\\\))",""); print $NF}'`; do
for component_version in `"$BOSH_CLI" interpolate $BOSH_FULL_PUBLIC_OPS_FILE_OPTIONS $BOSH_FULL_PRIVATE_OPS_FILE_OPTIONS "$BOSH_FULL_MANIFEST_FILE" --path /releases | awk '/^  version: \(\([a-z0-9_]+\)\)/{gsub("(\\\(|\\\))",""); print $NF}'`; do
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

	elif [ -n "$lower_value" ]; then
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

# Unfortunately, there is no way currently (2017/10/19) for Bosh/Director to automatically upload a stemcell in the same way it does for releases
if [ x"$REUPLOAD_STEMCELL" = x"true" -a -n "$STEMCELL_URL" ]; then
	[ -n "$BOSH_STEMCELL_VERSION" ] && URL_EXTENSION="?v=$BOSH_STEMCELL_VERSION"

	UPLOAD_URL="$STEMCELL_URL$URL_EXTENSION"

	INFO "Uploading $UPLOAD_URL to Bosh"
	"$BOSH_CLI" upload-stemcell --tty "$UPLOAD_URL"

elif [ x"$REUPLOAD_STEMCELL" = x"true" -a -z "$STEMCELL_URL" ]; then
	FATAL 'No STEMCELL_URL provided, unable to upload a stemcell'

fi

#if [ x"$RUN_BOSH_PREAMBLE" = x"true" -a x"$NORUN_BOSH_PREAMBLE" != x"true" ]; then
#	if [ x"$RUN_DRY_RUN" = x"true" -o -n "$DEBUG" ]; then
#		INFO 'Checking Bosh preamble dry-run'
#		"$BOSH_CLI" deploy \
#			--non-interactive \
#			--dry-run \
#			--tty \
#			--vars-env="$ENV_PREFIX_NAME" \
#			"$BOSH_PREAMBLE_MANIFEST_FILE"
#	fi
#
#	INFO 'Deploying Bosh preamble'
#	"$BOSH_CLI" deploy \
#		--non-interactive \
#		--tty \
#		--vars-env="$ENV_PREFIX_NAME" \
#		"$BOSH_PREAMBLE_MANIFEST_FILE"
#
#	# For some reason Bosh lists the errands in the preamble manifest and an additional one that has the same name
#	# as the release we install on the errand VMs (2017/09/07)
#	for _e in `"$BOSH_CLI" errands`; do
#		# TEMPORARY until the output of 'bosh errands' is fixed and only prints a list of errands
#		if ! awk -v errand="$_e" 'BEGIN{ rc=1 }/^- name:/{if($NF == errand) rc=0 }END{ exit rc }' "$BOSH_PREAMBLE_MANIFEST_FILE"; then
#			WARN "Ignoring non-existant errand: $_e"
#
#			ignored=1
#
#			continue
#		fi
#		# TEMPORARY
#
#		INFO "Running errand: $_e"
#		"$BOSH_CLI" run-errand --tty "$_e"
#	done
#
#	# TEMPORARY report when workaround is no longer required
#	[ -z "$ignored" ] && FATAL 'Working around additional errand is no longer required, please remove the sections between TEMPORARY & TEMPORARY'
#	# TEMPORARY
#
#	INFO 'Deleting Bosh premable deployment'
#	"$BOSH_CLI" delete-deployment --force --tty --non-interactive
#fi

# This is disabled by default as it causes a re-upload of releases/stemcells if their version(s) have been set to 'latest'
if [ x"$RUN_DRY_RUN" = x'true' -o -n "$DEBUG" ]; then
	INFO 'Checking Bosh deployment dry-run'
	sh -c "'$BOSH_CLI' deploy \
			--tty \
			--dry-run \
			--non-interactive \
			$BOSH_FULL_PUBLIC_OPS_FILE_OPTIONS \
			$BOSH_FULL_PRIVATE_OPS_FILE_OPTIONS \
			--ops-file='$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/full-variables.yml' \
			--vars-env='$ENV_PREFIX_NAME' \
			--vars-file='$BOSH_FULL_STATIC_IPS_YML' \
			--vars-store='$DEPLOYMENT_DIR_RELATIVE/full-var-store.yml' \
			'$BOSH_FULL_MANIFEST_FILE'"
fi

# ... finally we get around to running the Bosh/CF deployment
INFO 'Deploying Bosh'
sh -c "'$BOSH_CLI' deploy \
		--tty \
		--non-interactive \
		$BOSH_FULL_PUBLIC_OPS_FILE_OPTIONS \
		$BOSH_FULL_PRIVATE_OPS_FILE_OPTIONS \
		--ops-file='$MANIFESTS_DIR_RELATIVE/Bosh-Full-Manifests/full-variables.yml' \
		--vars-env='$ENV_PREFIX_NAME' \
		--vars-file='$BOSH_FULL_STATIC_IPS_YML' \
		--vars-store='$DEPLOYMENT_DIR_RELATIVE/full-var-store.yml' \
		'$BOSH_FULL_MANIFEST_FILE'"

# Do we need to run any errands (eg smoke tests, registrations)
if [ x"$SKIP_POST_DEPLOY_ERRANDS" != x"true" -a -n "$POST_DEPLOY_ERRANDS" ]; then
	INFO 'Running post deployment smoke tests'
	for _e in $POST_DEPLOY_ERRANDS; do
		INFO "Running errand: $_e"
		"$BOSH_CLI" run-errand --tty "$_e"
	done
elif [ x"$SKIP_POST_DEPLOY_ERRANDS" = x"true" ]; then
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
			gsub("\*","",$2)

			printf("%s_version='\''%s'\''\n",$1,$2)
		}
	}' >"$OUTPUT_FILE"
done

# Any post deploy script to run? These are under $POST_DEPLOY_SCRIPTS_DIR/cf
post_deploy_scripts cf

INFO 'Bosh VMs'
"$BOSH_CLI" vms

