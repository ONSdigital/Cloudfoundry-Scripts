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
	[ x"$DELETE_BOSH_STATE" = x"true" ] && rm -f "$BOSH_LITE_STATE_FILE"

	WARN "Existing Bootstrap Bosh state file exists: $BOSH_LITE_STATE_FILE"
fi

if [ ! -f "$PASSWORD_CONFIG_FILE" -o x"$REGENERATE_PASSWORDS" = x"true" ]; then
	# Environmental variables are insecure
	INFO 'Generating password config'
	echo '# Cloudfoundry passwords' >"$PASSWORD_CONFIG_FILE"
	for i in `sed $SED_EXTENDED -ne 's/.*\(\(([^).]*(password|secret))\)\).*/\1/gp' "$BOSH_FULL_MANIFEST_FILE" "$BOSH_LITE_MANIFEST_FILE" | sort -u`; do
		cat <<EOF
$i='`generate_password`'
EOF
	done >>"$PASSWORD_CONFIG_FILE"
fi

# Sanity check
[ -f "$PASSWORD_CONFIG_FILE" ] || FATAL "Password configuration file does not exist: '$PASSWORD_CONFIG_FILE'"

INFO 'Loading password configuration'
eval export `prefix_vars "$PASSWORD_CONFIG_FILE" "$ENV_PREFIX"`
# We set BOSH_CLIENT_SECRET to this later on
eval DIRECTOR_PASSWORD="\$${ENV_PREFIX}director_password"

if [ ! -d "$SSL_DIR" -o ! -f "$SSL_YML" -o x"$REGENERATE_SSL" = x"true" -o x"$DELETE_SSL_CA" = x"true" ]; then
	[ -d "$SSL_DIR" ] && rm -rf "$SSL_DIR"

	INFO 'Generating SSL CAs and keypairs'
	mkdir -p "$SSL_DIR"
	cd "$SSL_DIR"

	# $SSL_YML may contain spaces
	OUTPUT_YML="$SSL_YML" "$BASE_DIR/generate-ssl.sh" "$domain_name" "$INTERNAL_DOMAIN"

	cd -
fi

# Just in case
if [ ! -f "$EXTERNAL_SSL_DIR/client/director.$domain_name.key" -o ! -f "$EXTERNAL_SSL_DIR/client/director.$domain_name.crt" ]; then
	FATAL 'No director SSL keypair available'
fi

if [ -n "$BOSH_DIRECTOR_CONFIG" -a ! -f "$BOSH_DIRECTOR_CONFIG" -o x"$REGENERATE_BOSH_CONFIG" = x"true" ]; then
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

INFO 'Loading Bosh config'
[ -f "$BOSH_DIRECTOR_CONFIG" ] || FATAL "Bosh configuration file does not exist: '$BOSH_DIRECTOR_CONFIG'"
eval export `prefix_vars "$BOSH_DIRECTOR_CONFIG"`
eval export `prefix_vars "$BOSH_SSH_CONFIG" "$ENV_PREFIX"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
export BOSH_CA_CERT

# The file is recorded relative to the base directory, but Bosh changes its directory internally, whilst running, to the location of the manifest,
# so we need to make sure the SSH file is an absolute location
eval bosh_ssh_key_file="\$${ENV_PREFIX}bosh_ssh_key_file"
findpath "${ENV_PREFIX}bosh_ssh_key_file" "$bosh_ssh_key_file"

if [ -n "$DELETE_BOSH_ENV" -a x"$DELETE_BOSH_ENV" = x"true" ]; then
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

	NEW_BOSH_ENV='true'
fi

INFO 'Pointing Bosh at newly deployed Bosh'
"$BOSH" alias-env $BOSH_TTY_OPT -e "$BOSH_ENVIRONMENT" "$BOSH_ENVIRONMENT"

INFO 'Attempting to login'
"$BOSH" log-in $BOSH_TTY_OPT

INFO 'Setting CloudConfig'
"$BOSH" update-cloud-config "$BOSH_FULL_CLOUD_CONFIG_FILE" \
	$BOSH_INTERACTIVE_OPT \
	$BOSH_TTY_OPT \
	--var bosh_name="$DEPLOYMENT_NAME" \
	--var bosh_deployment="$BOSH_DEPLOYMENT" \
	--var bosh_lite_ip="$BOSH_ENVIRONMENT" \
	--vars-file="$SSL_YML" \
	--vars-env="$ENV_PREFIX_NAME" \
	--vars-store="$BOSH_FULL_VARS_FILE"

# Upload Stemcells & releases
[ x"$REUPLOAD_COMPONENTS" = x"true" -o x"$NEW_BOSH_ENV" = x"true" ] && "$BASE_DIR/upload_components.sh"

# Allow running of a custom script that can do other things (eg upload a local release)
[ -f "../pre_deploy.sh" -a -x "../pre_deploy.sh" ] && ../pre_deploy.sh

if [ x"$RERUN_BOSH_PREAMBLE" = x"true" -o x"$NEW_BOSH_ENV" = x"true" ]; then
	INFO 'Checking Bosh preamble dry-run'
	bosh_deploy "$DEPLOYMENT_NAME" "$BOSH_PREAMBLE_MANIFEST_FILE" "$BOSH_PREAMBLE_VARS_FILE" --dry-run

	INFO 'Deploying Bosh preamble'
	bosh_deploy "$DEPLOYMENT_NAME" "$BOSH_PREAMBLE_MANIFEST_FILE" "$BOSH_PREAMBLE_VARS_FILE"

	for _e in `"$BOSH" errands`; do
		"$BOSH" run-errand "$_e" --download-logs  --keep-alive
	done
fi

exit

INFO 'Checking Bosh deployment dry-run'
bosh_deploy "$DEPLOYMENT_NAME" "$BOSH_FULL_MANIFEST_FILE" "$BOSH_FULL_VARS_FILE" --dry-run
#"$BOSH" deploy "$BOSH_FULL_MANIFEST_FILE" \
#	--dry-run \
#	$BOSH_INTERACTIVE_OPT \
#	$BOSH_TTY_OPT \
#	--var bosh_name="$DEPLOYMENT_NAME" \
#	--var bosh_deployment="$BOSH_DEPLOYMENT" \
#	--var bosh_lite_ip="$BOSH_ENVIRONMENT" \
#	--vars-file="$SSL_YML" \
#	--vars-env="$ENV_PREFIX_NAME" \
#	--vars-store="$BOSH_FULL_VARS_FILE"

INFO 'Deploying Bosh'
bosh_deploy "$DEPLOYMENT_NAME" "$BOSH_FULL_MANIFEST_FILE" "$BOSH_FULL_VARS_FILE"
#"$BOSH" deploy "$BOSH_FULL_MANIFEST_FILE" \
#	$BOSH_INTERACTIVE_OPT \
#	$BOSH_TTY_OPT \
#	--var bosh_name="$DEPLOYMENT_NAME" \
#	--var bosh_deployment="$BOSH_DEPLOYMENT" \
#	--var bosh_lite_ip="$BOSH_ENVIRONMENT" \
#	--vars-file="$SSL_YML" \
#	--vars-env="$ENV_PREFIX_NAME" \
#	--vars-store="$BOSH_FULL_VARS_FILE"

INFO 'Cloudfoundry VMs'
"$BOSH" vms
