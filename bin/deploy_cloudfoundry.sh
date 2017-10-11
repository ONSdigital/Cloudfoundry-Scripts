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

if [ -f "$BOSH_LITE_STATE_FILE" ]; then
	if [ x"$DELETE_BOSH_ENV" = x"true" ]; then
		# If we have been asked to delete the Bosh env, we need to retain the state file, otherwise we cannot
		# find the correct VM to delete
		WARN "Not deleting Bootstrap Bosh state file as we need this to delete the Bootstrap Bosh environment"
		WARN "The state file will be deleted after we successfully, delete Bosh"
	elif [ x"$DELETE_BOSH_STATE" = x"true" ]; then
		rm -f "$BOSH_LITE_STATE_FILE"
	else
		WARN "Existing Bootstrap Bosh state file exists: $BOSH_LITE_STATE_FILE"
	fi
fi

if [ ! -f "$PASSWORD_CONFIG_FILE" -o x"$REGENERATE_PASSWORDS" = x"true" ]; then
	# Environmental variables are insecure
	INFO 'Generating password config'
	echo '# Cloudfoundry passwords' >"$PASSWORD_CONFIG_FILE"
	for i in `sed $SED_EXTENDED -ne 's/.*\(\(([^).]*(password|secret))\)\).*/\1/gp' "$BOSH_FULL_MANIFEST_FILE" "$BOSH_LITE_MANIFEST_FILE" | sort -u`; do
		# We don't want to generate passwords that are held in the AWS passwords file
		[ -f "$AWS_PASSWORD_CONFIG_FILE" ] && grep -Eq "^$i=" "$AWS_PASSWORD_CONFIG_FILE" && continue

		cat <<EOF
$i='`generate_password`'
EOF
	done >>"$PASSWORD_CONFIG_FILE"
fi

if [ ! -f "$NETWORK_CONFIG_FILE" -o x"$REGENERATE_NETWORKS_CONFIG" = x"true" ]; then
	INFO 'Generating network configuration'
	echo '# Cloudfoundry network configuration' >"$NETWORK_CONFIG_FILE"
	for i in `sed $SED_EXTENDED -ne 's/.*\(\(([^).]*)_cidr\)\).*/\1/gp' "$BOSH_FULL_CLOUD_CONFIG_FILE" "$BOSH_LITE_MANIFEST_FILE" | sort -u`; do
		eval cidr="\$${ENV_PREFIX}${i}_cidr"
		"$BASE_DIR/process_cidrs.sh" "$i" "$cidr"
	done >>"$NETWORK_CONFIG_FILE"
fi

# Sanity check
[ -f "$PASSWORD_CONFIG_FILE" ] || FATAL "Password configuration file does not exist: '$PASSWORD_CONFIG_FILE'"
[ -f "$AWS_PASSWORD_CONFIG_FILE" ] || FATAL "AWS Password configuration file does not exist: '$AWS_PASSWORD_CONFIG_FILE'"

INFO 'Loading password configuration'
eval export `prefix_vars "$PASSWORD_CONFIG_FILE" "$ENV_PREFIX"`
eval export `prefix_vars "$AWS_PASSWORD_CONFIG_FILE" "$ENV_PREFIX"`
# We set BOSH_CLIENT_SECRET to this later on
eval DIRECTOR_PASSWORD="\$${ENV_PREFIX}director_password"
INFO 'Setting Bosh deployment name'
export ${ENV_PREFIX}bosh_deployment="$DEPLOYMENT_NAME"

if [ x"$REGENERATE_SSL" = x"true" -o x"$DELETE_SSL_CA" = x"true" ] && [ -d "$SSL_DIR" ]; then
	INFO 'Regenerating SSL CAs and keypairs'
	rm -rf "$SSL_DIR"
fi

if [ -d "$SSL_DIR" ]; then
	INFO 'Checking if we need to generate any additional SSL CAs and/or keypairs'
else
	INFO 'Generating SSL CAs and keypairs'
	mkdir -p "$SSL_DIR"
fi

cd "$SSL_DIR"

# $SSL_YML may contain spaces
OUTPUT_YML="$SSL_YML" "$BASE_DIR/generate-ssl.sh" "$domain_name" "$INTERNAL_DOMAIN"

cd -

# Just in case
if [ ! -f "$EXTERNAL_SSL_DIR/client/director.$domain_name.key" -o ! -f "$EXTERNAL_SSL_DIR/client/director.$domain_name.crt" ]; then
	FATAL 'No director SSL keypair available'
fi

if [ -n "$BOSH_DIRECTOR_CONFIG" -a ! -f "$BOSH_DIRECTOR_CONFIG" -o x"$REGENERATE_BOSH_CONFIG" = x"true" ] || ! grep -Eq "^BOSH_CLIENT_SECRET='$DIRECTOR_PASSWORD'" "$BOSH_DIRECTOR_CONFIG"; then
	INFO 'Generating Bosh configurations'
	cat <<EOF >"$BOSH_DIRECTOR_CONFIG"
# Bosh deployment config
BOSH_ENVIRONMENT='$director_dns'
BOSH_DEPLOYMENT='$DEPLOYMENT_NAME'
BOSH_CLIENT_SECRET='$DIRECTOR_PASSWORD'
BOSH_CLIENT='director'
BOSH_CA_CERT='$EXTERNAL_SSL_DIR_RELATIVE/ca/$domain_name.crt'
EOF
fi

[ -f "$BOSH_DIRECTOR_CONFIG" ] || FATAL "Bosh configuration file does not exist: '$BOSH_DIRECTOR_CONFIG'"

INFO 'Loading Bosh config'
eval export `prefix_vars "$BOSH_DIRECTOR_CONFIG"`
INFO 'Loading Bosh SSH config'
eval export `prefix_vars "$BOSH_SSH_CONFIG" "$ENV_PREFIX"`
INFO 'Loading Bosh network configuration'
eval export `prefix_vars "$NETWORK_CONFIG_FILE" "$ENV_PREFIX"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
export BOSH_CA_CERT

# The file is recorded relative to the base directory, but Bosh changes its directory internally, whilst running, to the location of the manifest,
# so we need to make sure the SSH file is an absolute location
eval bosh_ssh_key_file="\$${ENV_PREFIX}bosh_ssh_key_file"
findpath "${ENV_PREFIX}bosh_ssh_key_file" "$bosh_ssh_key_file"

# Bosh doesn't seem to be able to handle templating (eg ((variable))) and variables files at the same time, so we need to expand the variables and then use
# the output when we do a bosh create-env/deploy
if [ ! -f "$LITE_STATIC_IPS_YML" -o "$REINTERPOLATE_LITE_STATIC_IPS" = x"true" ]; then
	# Create the initial YML header
	cat >"$BOSH_LITE_STATIC_IPS_YML" <<EOF
---
EOF
	bosh_int "$BOSH_LITE_STATIC_IPS_FILE" >>"$BOSH_LITE_STATIC_IPS_YML"
fi


if [ x"$DELETE_BOSH_ENV" = x"true" ]; then
	INFO 'Removing existing Bosh bootstrap environment'
	bosh_env delete-env

	rm -f "$BOSH_LITE_STATE_FILE"
fi

if [ ! -f "$BOSH_LITE_STATE_FILE" -o x"$REGENERATE_BOSH_ENV" = x"true" ]; then
	INFO 'Creating Bosh bootstrap environment'
	bosh_env create-env

	# Do not keep any state file if things fail
	if [ 0$? -ne 0 ]; then
		[ -z "$KEEP_BOSH_STATE" ] || rm -f "$BOSH_LITE_STATE_FILE"

		FATAL 'Bosh lite deployment failed'
	fi

	# We may not have created a new Bosh environment
	NEW_BOSH_ENV='true'
fi

INFO 'Pointing Bosh client at newly deployed Bosh Director'
"$BOSH" alias-env $BOSH_TTY_OPT -e "$BOSH_ENVIRONMENT" "$BOSH_ENVIRONMENT" >&2

INFO 'Attempting to login'
"$BOSH" log-in $BOSH_TTY_OPT >&2

if [ ! -f "$FULL_STATIC_IPS_YML" -o "$REINTERPOLATE_FULL_STATIC_IPS" = x"true" ]; then
	# Create the initial YML header
	cat >"$BOSH_FULL_STATIC_IPS_YML" <<EOF
---
EOF
	bosh_int "$BOSH_FULL_STATIC_IPS_FILE" >>"$BOSH_FULL_STATIC_IPS_YML"
fi

INFO 'Setting CloudConfig'
"$BOSH" update-cloud-config "$BOSH_FULL_CLOUD_CONFIG_FILE" \
	$BOSH_INTERACTIVE_OPT \
	$BOSH_TTY_OPT \
	--var bosh_deployment="$BOSH_DEPLOYMENT" \
	--vars-file="$SSL_YML" \
	--vars-file="$BOSH_FULL_STATIC_IPS_YML" \
	--vars-env="$ENV_PREFIX_NAME" \
	--vars-store="$BOSH_FULL_VARS_FILE"

# Upload Stemcells & releases
if [ x"$REUPLOAD_COMPONENTS" = x"true" -o x"$NEW_BOSH_ENV" = x"true" ]; then
	# At the moment (2017/09/11) and for a good few months, there has been a problem with some of the uploads:
	# Task 17 | 10:12:31 | Compiling packages: golang-1.8/63a243be32451af083a062ba2c929c3f2b34f132 (00:03:28)
	#	L Error: Action Failed get_task: Task b8160a99-e155-4b42-6eb2-cba0ae7488b7 result: Compiling package golang-1.8: Fetching package golang-1.8: Fetching package blob 33dacc88-3647-4469-9183-acfcefe24611: Getting blob from inner blobstore: Checking downloaded blob '33dacc88-3647-4469-9183-acfcefe24611': Expected stream to have digest 'dac8587b4ce06a0f647f0061984d308349af9d08' but was 'c25e7406a45fb901a085edc8a7b1769f6fb543dd'
	# https://github.com/cloudfoundry/cf-release/issues/1239
	"$BASE_DIR/upload_components.sh" "$DEPLOYMENT_NAME"
fi

# Allow running of a custom script that can do other things (eg upload a local release)
if [ x"$NORUN_PREDEPLOY" != x"true" -a -f "$TOP_LEVEL_DIR/pre_deploy.sh" ]; then
	[ -x "$TOP_LEVEL_DIR/pre_deploy.sh" ] || chmod +x "$TOP_LEVEL_DIR/pre_deploy.sh"

	"$TOP_LEVEL_DIR/pre_deploy.sh"
fi

# Not sure if it'd make more sense to reverse this logic and have an explicit run preamble
if [ x"$NORUN_BOSH_PREAMBLE" != x"true" ]; then
	INFO 'Checking Bosh preamble dry-run'
	bosh_deploy "$BOSH_PREAMBLE_MANIFEST_FILE" "$BOSH_PREAMBLE_VARS_FILE" --dry-run NO_OPS_FILES

	INFO 'Deploying Bosh preamble'
	bosh_deploy "$BOSH_PREAMBLE_MANIFEST_FILE" "$BOSH_PREAMBLE_VARS_FILE" NO_OPS_FILES

	# For some reason Bosh lists the errands in the preamble manifest and an additional one that has the same name
	# as the release we install on the errand VMs (2017/09/07)
	for _e in `"$BOSH" errands`; do
		# TEMPORARY until the output of 'bosh errands' is fixed and only prints a list of errands
		if ! awk -v errand="$_e" 'BEGIN{ rc=1 }/^- name:/{if($NF == errand) rc=0 }END{ exit rc }' "$BOSH_PREAMBLE_MANIFEST_FILE"; then
			WARN "Ignoring non-existant errand: $_e"

			ignored=1

			continue
		fi
		# TEMPORARY

		INFO "Running errand: $_e"
		"$BOSH" run-errand "$_e"
	done

	# TEMPORARY report when workaround is no longer required
	[ -z "$ignored" ] && FATAL 'Working around additional errand is no longer required, please remove the sections between TEMPORARY & TEMPORARY'
	# TEMPORARY

	INFO 'Deleting Bosh premable deployment'
	"$BOSH" delete-deployment --force $BOSH_INTERACTIVE_OPT $BOSH_TTY_OPT
fi

INFO 'Checking Bosh deployment dry-run'
bosh_deploy "$BOSH_FULL_MANIFEST_FILE" "$BOSH_FULL_VARS_FILE" --dry-run

INFO 'Deploying Bosh'
bosh_deploy "$BOSH_FULL_MANIFEST_FILE" "$BOSH_FULL_VARS_FILE"

if [ x"$SKIP_POST_DEPLOY_ERRANDS" != x"true" -a -n "$POST_DEPLOY_ERRANDS" ]; then
	INFO 'Running post deployment smoke tests'
	for _e in $POST_DEPLOY_ERRANDS; do
		INFO "Running errand: $_e"
		"$BOSH" run-errand "$_e"
	done
elif [ x"$SKIP_POST_DEPLOY_ERRANDS" = x"true" ]; then
	INFO 'Skipping run of post deploy errands' 

elif [ -z "$POST_DEPLOY_ERRANDS" ]; then
	INFO 'No post deploy errands to run'
fi

post_deploy_scripts CF

INFO 'Bosh VMs'
"$BOSH" vms

