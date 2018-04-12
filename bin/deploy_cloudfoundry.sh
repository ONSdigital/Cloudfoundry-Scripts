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
#	[BOSH_DIRECTOR_PRIVATE_IP]
#	UPGRADE_VERSIONS=[true|false]
#	REINTERPOLATE_DIRECTOR_STATIC_IPS=[true|false]
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

extract_prefixed_env_var() {
	eval echo \$"${1}_${2}"
}

# Check if we have any existing Bosh state
if [ -f "$BOSH_DIRECTOR_STATE_FILE" ]; then
	if [ x"$DELETE_BOSH_ENV" = x'true' ]; then
		# If we have been asked to delete the Bosh env, we need to retain the state file, otherwise we cannot
		# find the correct VM to delete
		WARN "Not deleting Bootstrap Bosh state file as we need this to delete the Bootstrap Bosh environment"
		WARN "The state file will be deleted after we successfully, delete Bosh"
	elif [ x"$DELETE_BOSH_STATE" = x'true' ]; then
		# If we have manually deleted the Bosh VM, we should delete the state file
		INFO 'Removing Bosh state file'
		rm -f "$BOSH_DIRECTOR_STATE_FILE"
	else
		WARN "Existing Bootstrap Bosh state file exists: $BOSH_DIRECTOR_STATE_FILE"
	fi
fi

findpath manifest_dir "${MANIFESTS_DIR_RELATIVE}"

# Do we need to generate the network configuration?
if [ ! -f "$NETWORK_CONFIG_FILE" -o x"$REGENERATE_NETWORKS_CONFIG" = x'true' ]; then
	INFO 'Generating network configuration'
	echo '# Cloudfoundry network configuration' >"$NETWORK_CONFIG_FILE"
	for i in `sed $SED_EXTENDED -ne 's/.*\(\(([^).]*)_cidr\)\).*/\1/gp' "$BOSH_CLOUD_CONFIG_FILE" "$BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE" "${manifest_dir}/Bosh-Director-Manifests/operations/networks.yml" | sort -u`; do
		eval cidr="\$${ENV_PREFIX}${i}_cidr"
		"$BASE_DIR/process_cidrs.sh" "$i" "$cidr"
	done >>"$NETWORK_CONFIG_FILE"

	REGENERATE_NETWORKS_CONFIG=true
fi

INFO 'Loading Bosh SSH config'
export_file_vars "$BOSH_SSH_CONFIG" "$ENV_PREFIX"
INFO 'Loading Bosh network configuration'
export_file_vars "$NETWORK_CONFIG_FILE" "$ENV_PREFIX"

if [ -n "$BOSH_DIRECTOR_PRIVATE_IP" ]; then

	grep -Eq "^director_az[1-9]_reserved_ip[0-9]+='$BOSH_DIRECTOR_PRIVATE_IP'$" "$NETWORK_CONFIG_FILE" || \
		FATAL "Bosh Director/Director IP '$BOSH_DIRECTOR_PRIVATE_IP' does not exist as a reserved IP within '$NETWORK_CONFIG_FILE'"
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
# We don't want the interpolated Bosh Director manifest to contain a full path to the SSH file
#findpath "${ENV_PREFIX}bosh_ssh_key_file" "$bosh_ssh_key_file"

# Remove Bosh?
if [ x"$DELETE_BOSH_ENV" = x'true' ]; then
	INFO 'Removing existing Bosh bootstrap environment'
	"$BOSH_CLI" delete-env \
		--tty \
		--state="$BOSH_DIRECTOR_STATE_FILE" \
		"$BOSH_DIRECTOR_INTERPOLATED_MANIFEST"

	# ... and cleanup any state
	rm -f "$BOSH_DIRECTOR_STATE_FILE"
fi

if [ x"$NO_CREATE_RELEASES" != x'true' -o ! -f "$BOSH_DIRECTOR_RELEASES" ]; then
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
			update_yml_var "$BOSH_DIRECTOR_RELEASES" "$release_url_varname" "$release_url_value"

			UPLOAD_RELEASES='true'
		fi
	done
fi

if [ ! -f "$BOSH_DIRECTOR_STATE_FILE" ]; then
	CREATE_ACTION='Creating'
	STORE_ACTION='Storing'
else
	CREATE_ACTION='Updating'
	STORE_ACTION='Potentially updating'
fi

INFO 'Interpolating Bosh Director manifest'

findpath bosh_deployment_dir "${BOSH_DEPLOYMENT_DIR}"

director_ops_file_options="-o '${manifest_dir}/Bosh-Director-Manifests/operations/bosh-password.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/certs.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/cloud-provider.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/director-user.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/networks.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/ntp.yml'"

# Re-add this ops file when ci server has iam instance profile
# -o '${bosh_deployment_dir}/aws/cli-iam-instance-profile.yml' \

director_aws_ops_file_options="-o '${bosh_deployment_dir}/aws/cpi.yml' \
-o '${bosh_deployment_dir}/aws/iam-instance-profile.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/aws/databases.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/aws/default-iam-instance-profile.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/aws/elb.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/aws/s3-blobstore.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/aws/s3-compiled-package-cache.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/aws/security-groups.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/aws/ssh.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/aws/tags.yml' \
-o '${manifest_dir}/Bosh-Director-Manifests/operations/aws/registry.yml'"

sh -c "'$BOSH_CLI' interpolate \
	--var-errs \
	--var='az=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" aws_availability_zone1)' \
	--var='default_key_name=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" bosh_ssh_key_name)' \
	--var='iam_instance_profile=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" director_instance_profile)' \
	--var='default_security_groups=[$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" director_instance_security_group)]' \
	--var='internal_ip=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" director_az1_reserved_ip6)' \
	--var='subnet_id=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" director_az1_subnet)' \
	--var='region=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" aws_region)' \
	--var='director_name=cf-bosh-director' \
	--var='access_key_id=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" bosh_aws_access_key_id)' \
	--var='secret_access_key=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" bosh_aws_secret_access_key)' \
	--vars-env='$ENV_PREFIX_NAME' \
	--vars-file='$BOSH_DIRECTOR_RELEASES' \
	--vars-store='$BOSH_DIRECTOR_VARS_STORE' \
	$director_ops_file_options \
	$director_aws_ops_file_options \
	'$BOSH_DIRECTOR_MANIFEST_FILE'" >"$BOSH_DIRECTOR_INTERPOLATED_MANIFEST"

INFO "$CREATE_ACTION Bosh environment"
"$BOSH_CLI" create-env --tty --state="$BOSH_DIRECTOR_STATE_FILE" "$BOSH_DIRECTOR_INTERPOLATED_MANIFEST"

INFO "$STORE_ACTION Bosh Director CA certificate"
"$BOSH_CLI" interpolate --no-color --var-errs --path=/director_ssl/ca "$BOSH_DIRECTOR_VARS_STORE" >"$DEPLOYMENT_DIR_RELATIVE/director_ca.crt"

INFO "$STORE_ACTION Bosh Director password"
BOSH_CLIENT_SECRET="$("$BOSH_CLI" interpolate --no-color --var-errs --path='/director_password' "$BOSH_DIRECTOR_VARS_STORE")"

if [ -n "$BOSH_DIRECTOR_CONFIG" -a ! -f "$BOSH_DIRECTOR_CONFIG" -o x"$REGENERATE_BOSH_CONFIG" = x'true' ] || ! grep -Eq "^BOSH_CLIENT_SECRET='$BOSH_CLIENT_SECRET'" "$BOSH_DIRECTOR_CONFIG"; then
	INFO 'Generating Bosh configuration'
	cat <<EOF >"$BOSH_DIRECTOR_CONFIG"
# Bosh deployment config
BOSH_ENVIRONMENT='$director_dns'
BOSH_CLIENT_SECRET='$BOSH_CLIENT_SECRET'
BOSH_CLIENT='director'
BOSH_CA_CERT='$DEPLOYMENT_DIR_RELATIVE/director_ca.crt'
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

# Bosh doesn't expand variables from within variables files
INFO 'Generating Cloud Config Variables'
"$BOSH_CLI" interpolate --var-errs \
	--vars-env="$ENV_PREFIX_NAME" \
	"$BOSH_CLOUD_VARIABLES_AVAILABILITY_FILE" >"$BOSH_CF_INTERPOLATED_CLOUD_CONFIG_VARS"

INFO 'Setting Cloud Config'
"$BOSH_CLI" update-cloud-config --tty --vars-env="$ENV_PREFIX_NAME" \
	--var="cc_instance_profile=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" cc_bucket_access_instance_profile)" \
	--var="cf_router_lb_group=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" application_elb_target_group_tcp80)" \
	--var="cf_router_sec_group=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" router_security_group)" \
	--var="cf_router_tls_lb_group=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" application_elb_target_group_tcp443)" \
	--var="cf_ssh_lb_elb=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" cf_ssh_elb)" \
	--var="diego_ssh_sec_group=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" cf_ssh_instance_security_group)" \
	--vars-file="$BOSH_CF_INTERPOLATED_CLOUD_CONFIG_VARS" "$BOSH_CLOUD_CONFIG_FILE"

findpath bosh_cf_deployment_dir "${BOSH_CF_DEPLOYMENT_DIR}"

cf_ops_file_options="-o '${bosh_cf_deployment_dir}/operations/use-compiled-releases.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/app-domain.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/app-scale.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/cf-admin-user.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/consul-locket.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/custom-buildpacks.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/disable-tcp-router.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/password-policy.yml'"

cf_aws_ops_file_options="-o '${bosh_cf_deployment_dir}/operations/use-external-dbs.yml' \
-o '${bosh_cf_deployment_dir}/operations/use-s3-blobstore.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/aws/cc-instance-profile.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/aws/databases.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/aws/lb-security-groups.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/aws/running-security-groups.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/aws/s3-blobstore-instance-profile.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/operations/aws/tags.yml'"

if [ $CPI_TYPE = "AWS" ]; then
	if [ "${availability_type}" = single ]; then
		availability_ops_file="-o '${manifest_dir}/Bosh-CF-Manifests/operations/aws/single-az.yml'"
	fi
fi

cf_db_dns=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" cf_db_dns)

INFO 'Interpolating Bosh CF manifest'
sh -c "'$BOSH_CLI' interpolate \
	--no-color \
	--var-errs \
	--var='system_domain=system.$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" domain_name)' \
	--var='app_package_directory_key=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" package_bucket)' \
	--var='buildpack_directory_key=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" buildpack_bucket)' \
	--var='droplet_directory_key=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" droplet_bucket)' \
	--var='resource_directory_key=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" resource_bucket)' \
	--var='postgresql_backup_vm_type=default' \
	--var='external_bbs_database_address=${cf_db_dns}' \
	--var='external_bbs_database_name=diego' \
	--var='external_bbs_database_password=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /diego_db_password "${BOSH_DIRECTOR_VARS_STORE}")' \
	--var='external_bbs_database_username=diego' \
	--var='external_database_port=$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" cf_db_port)' \
	--var='external_database_type=postgres' \
	--var='external_locket_database_address=${cf_db_dns}' \
	--var='external_locket_database_name=locket' \
	--var='external_locket_database_password=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /locket_db_password "${BOSH_DIRECTOR_VARS_STORE}")' \
	--var='external_locket_database_username=locket' \
	--var='external_policy_server_database_address=${cf_db_dns}' \
	--var='external_policy_server_database_name=policy_server' \
	--var='external_policy_server_database_password=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /policy_server_db_password "${BOSH_DIRECTOR_VARS_STORE}")' \
	--var='external_policy_server_database_username=policy_server' \
	--var='external_routing_api_database_address=${cf_db_dns}' \
	--var='external_routing_api_database_name=routing_api' \
	--var='external_routing_api_database_password=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /routing_api_db_password "${BOSH_DIRECTOR_VARS_STORE}")' \
	--var='external_routing_api_database_username=routing_api' \
	--var='external_silk_controller_database_address=${cf_db_dns}' \
	--var='external_silk_controller_database_name=silk' \
	--var='external_silk_controller_database_password=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /silk_db_password "${BOSH_DIRECTOR_VARS_STORE}")' \
	--var='external_silk_controller_database_username=silk' \
	--var='external_uaa_database_address=${cf_db_dns}' \
	--var='external_uaa_database_name=uaadb' \
	--var='external_uaa_database_password=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /uaa_db_password "${BOSH_DIRECTOR_VARS_STORE}")' \
	--var='external_uaa_database_username=uaaadmin' \
	--var='external_cc_database_name=ccdb' \
	--var='external_cc_database_address=${cf_db_dns}' \
	--var='external_cc_database_password=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /cc_db_password "${BOSH_DIRECTOR_VARS_STORE}")' \
	--var='external_cc_database_username=ccadmin' \
	--vars-env='$ENV_PREFIX_NAME' \
	--vars-store='$BOSH_CF_VARIABLES_STORE' \
	$cf_ops_file_options \
	$cf_aws_ops_file_options \
	$availability_ops_file \
	'$BOSH_CF_MANIFEST_FILE'" >"$BOSH_CF_INTERPOLATED_MANIFEST"

INFO 'Checking if we need to upload any stemcells'
stemcell_version=$("$BOSH_CLI" interpolate --no-color --var-errs --path /stemcells/alias=default/version "$BOSH_CF_INTERPOLATED_MANIFEST")
"$BOSH_CLI" stemcells --no-color | awk -v stemcell="${stemcell_version}" 'BEGIN{ rc=1 }{if($3 == stemcell) rc=0 }END{ exit rc }' || UPLOAD_STEMCELL='true'

# Unfortunately, there is no way currently (2017/10/19) for Bosh/Director to automatically upload a stemcell in the same way it does for releases
if [ x"$UPLOAD_STEMCELL" = x'true' -o x"$REUPLOAD_STEMCELL" = x'true' ]; then
	if [ "${CPI_TYPE}" = AWS ] && [ ! "${stemcell_version}" = "" ]; then
		STEMCELL_URL="https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent?v=${stemcell_version}"
	fi

	if [ -z "$STEMCELL_URL" ]; then
		WARN 'No STEMCELL_URL provided, finding stemcell details from Bosh Director deployment'

		STEMCELL_URL="`"$BOSH_CLI" interpolate --no-color --path '/resource_pools/name=vms/stemcell/url' "$BOSH_DIRECTOR_INTERPOLATED_MANIFEST"`"

		[ -z "$STEMCELL_URL" ] && FATAL "Unable to determine Stemcell URL from '$BOSH_DIRECTOR_INTERPOLATED_MANIFEST' path '/resource_pools/name=*/stemcell'"
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

# Upload any releases from the releases directory. e.g postgresql-databases-release
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
	"$BOSH_CLI" deploy --tty --dry-run "$BOSH_CF_INTERPOLATED_MANIFEST"
fi

INFO 'Setting up CF admin credentials'
SECRET="`"$BOSH_CLI" interpolate --no-color --path '/uaa_admin_client_secret' "$BOSH_CF_VARIABLES_STORE"`"
PASSWORD="`"$BOSH_CLI" interpolate --no-color --path '/cf_admin_password' "$BOSH_CF_VARIABLES_STORE"`"

        cat >"$CF_CREDENTIALS" <<EOF
# Cloudfoundry credentials
CF_ADMIN_USERNAME='cf_admin'
CF_ADMIN_PASSWORD='$PASSWORD'
CF_ADMIN_CLIENT_SECRET='$SECRET'
EOF

# ... finally we get around to running the CF deployment
INFO 'Deploying CF'
"$BOSH_CLI" deploy -d cf --tty "$BOSH_CF_INTERPOLATED_MANIFEST"

if [ "$SKIP_POST_DEPLOY_ERRANDS" != 'true' ]; then
	"$BOSH_CLI" run-errand -d cf --tty smoke-tests
fi

# Only valid smoke test with cf-deployment is 'smoke-tests'
# Do we need to run any errands (eg smoke tests, registrations)
# if [ x"$SKIP_POST_DEPLOY_ERRANDS" != x'true' -a -n "$POST_DEPLOY_ERRANDS" ]; then
# 	INFO 'Running post deployment smoke tests'
# 	for _e in $POST_DEPLOY_ERRANDS; do
# 		INFO "Running errand: $_e"
# 		"$BOSH_CLI" run-errand -d cf --tty "$_e"
# 	done
# elif [ x"$SKIP_POST_DEPLOY_ERRANDS" = x'true' ]; then
# 	INFO 'Skipping run of post deploy errands'

# elif [ -z "$POST_DEPLOY_ERRANDS" ]; then
# 	INFO 'No post deploy errands to run'
# fi

if [ $CPI_TYPE = "AWS" ]; then
	if [ "${availability_type}" = single ]; then
		rmq_availability_ops_file="-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/aws/single-az.yml'"
	else
		rmq_availability_ops_file="-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/aws/multi-az.yml'"
	fi
fi

INFO 'Interpolating Bosh RabbitMQ manifest'

findpath bosh_rmq_deployment_dir "${BOSH_RMQ_DEPLOYMENT_DIR}"

rmq_ops_file_options="-o '${bosh_rmq_deployment_dir}/manifests/add-cf-rabbitmq.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/broker-password.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/log-level.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/use-ha-proxy-hosts.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/rmq-network.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/plugins.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/ports.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/remove-director-uuid.yml'"

rmq_aws_ops_file_options="-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/aws/vm-type.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/aws/broker-sec-group.yml' \
-o '${manifest_dir}/Bosh-CF-Manifests/bosh-rmq-broker/operations/aws/tags.yml'"

sh -c "'$BOSH_CLI' interpolate \
	--no-color \
	--var-errs \
	--var='stemcell-version=\"$("${BOSH_CLI}" interpolate --no-color --var-errs --path /stemcells/alias=default/version "$BOSH_CF_INTERPOLATED_MANIFEST")\"' \
	--var='deployment-name=rabbitmq-broker' \
	--var='bosh-domain=system.$(extract_prefixed_env_var "${ENV_PREFIX_NAME}" domain_name)' \
	--var='rabbitmq-broker-hostname=rmq-broker' \
	--var='multitenant-rabbitmq-broker-username=rmq-broker-user' \
	--var='product-name=rabbitmq' \
	--var='rabbitmq-broker-uuid=29727856-3a37-4c62-8adf-14b75bf599dc' \
	--var='rabbitmq-broker-plan-uuid=b44c9b16-fba0-4af2-8bdb-51b6902e1661' \
	--var='rabbitmq-management-hostname=rmq-mgmt' \
	--var='rabbitmq-broker-username=rmq-broker-admin' \
	--var='rabbitmq-management-username=rmq-mgmt-user' \
	--var='cf-admin-username=cf_admin' \
	--var='cf-admin-password=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /cf_admin_password "$BOSH_CF_VARIABLES_STORE")' \
	--var='rabbitmq-broker-protocol=https' \
	--var='cluster-partition-handling-strategy=pause_minority' \
	--var='disk_alarm_threshold=\"{mem_relative,0.4}\"' \
	--var='haproxy-stats-username=haproxy-stats-user' \
	--var='consul_release_url=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /releases/name=consul/url "$BOSH_CF_INTERPOLATED_MANIFEST")' \
	--var='consul_release_version=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /releases/name=consul/version "$BOSH_CF_INTERPOLATED_MANIFEST")' \
	--var='consul_release_sha1=$("${BOSH_CLI}" interpolate --no-color --var-errs --path /releases/name=consul/sha1 "$BOSH_CF_INTERPOLATED_MANIFEST")' \
	--vars-env='$ENV_PREFIX_NAME' \
	--vars-store='$BOSH_RMQ_VARIABLES_STORE' \
	$rmq_ops_file_options \
	$rmq_aws_ops_file_options \
	$rmq_availability_ops_file \
	'$BOSH_RMQ_MANIFEST_FILE'" >"$BOSH_RMQ_INTERPOLATED_MANIFEST"

INFO 'Uploading rabbitmq releases'
"$BOSH_CLI" upload-release https://bosh.io/d/github.com/pivotal-cf/cf-rabbitmq-release?v=241.0.0 --sha1 5ef82d43d29e3d3e65e4939707988b2b81f8aa1b
"$BOSH_CLI" upload-release https://bosh.io/d/github.com/pivotal-cf/cf-rabbitmq-multitenant-broker-release?v=14.0.0 --sha1 34ac077456ffc607f64c9a4a783db5c208772dd2

INFO 'Deploying RabbitMQ'
"$BOSH_CLI" deploy -d rabbitmq-broker --tty "$BOSH_RMQ_INTERPOLATED_MANIFEST"

if [ "$SKIP_POST_DEPLOY_ERRANDS" != 'true' ]; then
	"$BOSH_CLI" run-errand -d rabbitmq-broker --tty broker-registrar
	"$BOSH_CLI" run-errand -d rabbitmq-broker --tty smoke-tests
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
