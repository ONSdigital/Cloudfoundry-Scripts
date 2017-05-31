#!/bin/sh
#
# default vcap password c1oudc0w
#
# https://bosh.io/docs/addons-common.html#misc-users
#
# Set specific stemcell & release versions and match manifest & upload_releases_stemcells.sh

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

# Set secure umask - the default permissions for ~/.bosh/config are wide open
INFO 'Setting secure umask'
umask 077

DEPLOYMENT_NAME="$1"
BOSH_FULL_MANIFEST_NAME="${2:-Bosh-Template}"
BOSH_CLOUD_MANIFEST_NAME="${3:-$BOSH_FULL_MANIFEST_NAME-AWS-CloudConfig}"
BOSH_LITE_MANIFEST_NAME="${4:-$BOSH_FULL_MANIFEST_NAME}"
AWS_ACCESS_KEY_ID="${5:-$AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${6:-$AWS_SECRET_ACCESS_KEY}"
MANIFESTS_DIR="${7:-Bosh-Manifests}"
INTERNAL_DOMAIN="${8:-cf.internal}"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'No Bosh deployment name provided'

grep -Eiq '^([[:alnum:]]+-?[[:alnum:]])+$' <<EOF || FATAL 'Invalid domain name, must be a valid domain label'
$DEPLOYMENT_NAME
EOF

# Expand manifests dir to full path
findpath MANIFESTS_DIR "$MANIFESTS_DIR"

#
DEPLOYMENT_FOLDER="$DEPLOYMENT_DIRECTORY/$DEPLOYMENT_NAME"
DEPLOYMENT_FOLDER_RELATIVE="$DEPLOYMENT_DIRECTORY_RELATIVE/$DEPLOYMENT_NAME"

#
BOSH_LITE_STATE_FILE="$DEPLOYMENT_FOLDER/$BOSH_LITE_MANIFEST_NAME-Lite-state.json"
BOSH_LITE_VARS_FILE="$DEPLOYMENT_FOLDER/$BOSH_LITE_MANIFEST_NAME-Lite-vars.yml"
BOSH_FULL_VARS_FILE="$DEPLOYMENT_FOLDER/$BOSH_FULL_MANIFEST_NAME-Full-vars.yml"
#
BOSH_LITE_MANIFEST_FILE="$MANIFESTS_DIR/Bosh-Lite-Manifests/$BOSH_LITE_MANIFEST_NAME.yml"
BOSH_FULL_MANIFEST_FILE="$MANIFESTS_DIR/Bosh-Full-Manifests/$BOSH_FULL_MANIFEST_NAME.yml"
BOSH_FULL_CLOUD_CONFIG_FILE="$MANIFESTS_DIR/Bosh-Full-Manifests/$BOSH_CLOUD_MANIFEST_NAME.yml"
#
SSL_FOLDER="$DEPLOYMENT_FOLDER/ssl"
SSL_FOLDER_RELATIVE="$DEPLOYMENT_FOLDER_RELATIVE/ssl"
SSL_YML="$SSL_FOLDER/ssl_config.yml"
#
CLOUD_OUTPUTS_CONFIG_FILE="$DEPLOYMENT_FOLDER/outputs.sh"
PASSWORD_CONFIG_FILE="$DEPLOYMENT_FOLDER/passwords.sh"
#
BOSH_SSH_CONFIG_FILE="$DEPLOYMENT_FOLDER/bosh-ssh.sh"
BOSH_CONFIG_FILE="$DEPLOYMENT_FOLDER/bosh-config.sh"

# Set prefix for vars that Bosh will suck in
ENV_PREFIX_NAME='CF_BOSH'
ENV_PREFIX="${ENV_PREFIX_NAME}_"

# Check for required config
[ -d "$MANIFESTS_DIR" ] || FATAL "$MANIFESTS_DIR directory does not exist"
[ -f "$CLOUD_OUTPUTS_CONFIG_FILE" ] || FATAL "Cloud outputs file '$CLOUD_OUTPUTS_CONFIG_FILE' does not exist"
[ -f "$BOSH_LITE_MANIFEST_FILE" ] || FATAL "Bosh lite manifest file '$BOSH_LITE_MANIFEST_FILE' does not exist"
[ -f "$BOSH_FULL_MANIFEST_FILE" ] || FATAL "Bosh manifest file '$BOSH_FULL_MANIFEST_FILE' does not exist"

# Behaviour modifications
# Other options include: SKIP_SSL_GENERATION, SKIP_PASSWORD_GENERATION, SKIP_BOSH_CREATE_ENV, SKIP_COMPONENT_UPLOAD
[ -f "$BOSH_LITE_STATE_FILE" -a -n "$DELETE_BOSH_STATE" -a x"$DELETE_BOSH_STATE" != x"false" ] && rm -f "$BOSH_LITE_STATE_FILE"

# Run non-interactively?
[ -n "$INTERACTIVE" ] || BOSH_INTERACTIVE_OPT="--non-interactive"

# Without a TTY (eg within Jenkins) Bosh doesn't seem to output anything when deploying
[ -z "$NO_FORCE_TTY" ] && BOSH_TTY_OPT="--tty"

if [ -z "$SKIP_STATE_CHECK" -o x"$SKIP_STATE_CHECK" = x"false" ] && [ -f "$BOSH_LITE_STATE_FILE" ]; then
	FATAL "Existing Bootstrap Bosh state file exists, please remove before continuing: $BOSH_LITE_STATE_FILE"
fi

# Check we have bosh installed
installed_bin bosh

INFO "Loading '$DEPLOYMENT_NAME' config"
eval export `prefix_vars "$CLOUD_OUTPUTS_CONFIG_FILE" "$ENV_PREFIX"`

INFO 'Setting additional variables'
export ${ENV_PREFIX}internal_domain="$INTERNAL_DOMAIN"
eval domain_name="\$${ENV_PREFIX}domain_name"
eval director_dns="\$${ENV_PREFIX}director_dns"
eval deployment_name="\$${ENV_PREFIX}deployment_name"
INTERNAL_SSL_FOLDER="$SSL_FOLDER/$internal_domain"
EXTERNAL_SSL_FOLDER="$SSL_FOLDER/$domain_name"
# Used for Bosh CA cert
EXTERNAL_SSL_FOLDER_RELATIVE="$SSL_FOLDER_RELATIVE/$domain_name"

[ x"$deployment_name" != x"$DEPLOYMENT_NAME" ] && FATAL "Deployment names do not match: $deployment_name != $DEPLOYMENT_NAME"

if [ -z "$SKIP_PASSWORD_GENERATION" -o x"$SKIP_PASSWORD_GENERATION" = x"false" -o ! -f "$PASSWORD_CONFIG_FILE" ]; then
	# Environmental variables are insecure
	INFO 'Generating password config'
	echo '# Cloudfoundry passwords' >"$PASSWORD_CONFIG_FILE"
	for i in `sed -nre 's/.*\(\(([^).]*(password|secret)[^).]*)\)\).*/\1/gp' "$BOSH_FULL_MANIFEST_FILE" "$BOSH_LITE_MANIFEST_FILE" | sort -u`; do
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

[ -d "$SSL_FOLDER" -a -n "$DELETE_SSL_CA" -a x"$DELETE_SSL_CA" != x"false" ] && rm -rf "$SSL_FOLDER"

if [ -z "$SKIP_SSL_GENERATION" -o x"$SKIP_SSL_GENERATION" = x"false" -o ! -f "$SSL_YML"  ]; then
	INFO 'Generating SSL CAs and keypairs'
	mkdir -p "$SSL_FOLDER"
	cd "$SSL_FOLDER"

	# $SSL_YML may contain spaces
	OUTPUT_YML="$SSL_YML" "$BASE_DIR/generate-ssl.sh" "$domain_name" "$INTERNAL_DOMAIN"

	cd -
fi

# Just in case
if [ ! -f "$EXTERNAL_SSL_FOLDER/client/director.$domain_name.key" -o ! -f "$EXTERNAL_SSL_FOLDER/client/director.$domain_name.crt" ]; then
	FATAL 'No director SSL keypair available'
fi

if [ -z "$SKIP_BOSH_CONFIG_CREATION" -o x"$SKIP_BOSH_CONFIG_CREATION" != x"false" ]; then
	# Cheat and generate both the LITE and FULL configs
	INFO 'Generating Bosh configurations'
	cat <<EOF >"$BOSH_CONFIG_FILE"
# Bosh deployment config
BOSH_ENVIRONMENT='$director_dns'
BOSH_DEPLOYMENT='$DEPLOYMENT_NAME'
BOSH_CLIENT_SECRET='$DIRECTOR_PASSWORD'
BOSH_CLIENT='director'
BOSH_CA_CERT='$EXTERNAL_SSL_FOLDER_RELATIVE/ca/$domain_name.crt'
EOF
fi

INFO 'Loading Bosh config'
[ -f "$BOSH_CONFIG_FILE" ] || FATAL "Bosh configuration file does not exist: '$BOSH_CONFIG_FILE'"
eval export `prefix_vars "$BOSH_CONFIG_FILE"`
eval export `prefix_vars "$BOSH_SSH_CONFIG_FILE" "$ENV_PREFIX"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
export BOSH_CA_CERT

# The file is recorded relative to the base directory, but Bosh changes its directory internally, whilst running, to the location of the manifest,
# so we need to make sure the SSH file is an absolute location
eval bosh_ssh_key_file="\$${ENV_PREFIX}bosh_ssh_key_file"
findpath "${ENV_PREFIX}bosh_ssh_key_file" "$bosh_ssh_key_file"

if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" ]; then
	INFO 'Loading AWS credentials'
	eval export `parse_aws_credentials | prefix_vars -`
else
	INFO 'Setting AWS credentials'
	aws_access_key_id="$AWS_ACCESS_KEY_ID"
	aws_secret_access_key="$AWS_SECRET_ACCESS_KEY"
fi

if [ -z "$SKIP_BOSH_CREATE_ENV" -o x"$SKIP_BOSH_CREATE_ENV" = x"false" -o x"$BOSH_DELETE_ENV" = x"true" -o ! -f "$BOSH_LITE_STATE_FILE" ]; then
	# These will probably be relocated once Bosh full has a director
	[ -z "$aws_access_key_id" ] && FATAL 'No AWS access key ID provided'
	[ -z "$aws_secret_access_key" ] && FATAL 'No AWS secret access key provided'

	if [ x"$BOSH_DELETE_ENV" = x"true" ]; then
		CREATE_OPT='delete-env'
		INFO 'Deleting Bosh bootstrap environment'
	else
		CREATE_OPT='create-env'
		INFO 'Creating Bosh bootstrap environment'
	fi

	"$BOSH" "$CREATE_OPT" "$BOSH_LITE_MANIFEST_FILE" \
		$BOSH_INTERACTIVE_OPT \
		$BOSH_TTY_OPT \
		--var bosh_name="$DEPLOYMENT_NAME" \
		--var bosh_deployment="$BOSH_DEPLOYMENT" \
		--var aws_access_key_id="$aws_access_key_id" \
		--var aws_secret_access_key="$aws_secret_access_key" \
		--state="$BOSH_LITE_STATE_FILE" \
		--vars-env="$ENV_PREFIX_NAME" \
		--vars-file="$SSL_YML" \
		--vars-store="$BOSH_LITE_VARS_FILE" || bosh_rc=$?

	# Do not keep any state file if things fail
	if [ 0$bosh_rc -ne 0 ]; then
		rm -f "$BOSH_LITE_STATE_FILE"

		FATAL 'Bosh lite deployment failed'
	fi

	[ x"$BOSH_DELETE_ENV" = x"true" ] && exit 0
fi

INFO 'Pointing Bosh at newly deployed Bosh'
"$BOSH" alias-env $BOSH_TTY_OPT -e "$director_dns" "$BOSH_ENVIRONMENT"

INFO 'Attempting to login'
"$BOSH" log-in $BOSH_TTY_OPT

# Upload Stemcells & releases
[ -z "$SKIP_COMPONENT_UPLOAD" -o x"$SKIP_COMPONENT_UPLOAD" = x"false" ] && "$BASE_DIR/upload_components.sh"

INFO 'Setting CloudConfig'
"$BOSH" update-cloud-config "$BOSH_FULL_CLOUD_CONFIG_FILE" \
	$BOSH_INTERACTIVE_OPT \
	$BOSH_TTY_OPT \
	--var bosh_name="$DEPLOYMENT_NAME" \
	--var bosh_deployment="$BOSH_DEPLOYMENT" \
	--var bosh_lite_ip="$director_dns" \
	--vars-file="$SSL_YML" \
	--vars-env="$ENV_PREFIX_NAME" \
	--vars-store="$BOSH_FULL_VARS_FILE"

INFO 'Checking Bosh deployment dry-run'
"$BOSH" deploy "$BOSH_FULL_MANIFEST_FILE" \
	--dry-run \
	$BOSH_INTERACTIVE_OPT \
	$BOSH_TTY_OPT \
	--var bosh_name="$DEPLOYMENT_NAME" \
	--var bosh_deployment="$BOSH_DEPLOYMENT" \
	--var bosh_lite_ip="$director_dns" \
	--vars-file="$SSL_YML" \
	--vars-env="$ENV_PREFIX_NAME" \
	--vars-store="$BOSH_FULL_VARS_FILE"

INFO 'Deploying Bosh'
"$BOSH" deploy "$BOSH_FULL_MANIFEST_FILE" \
	$BOSH_INTERACTIVE_OPT \
	$BOSH_TTY_OPT \
	--var bosh_name="$DEPLOYMENT_NAME" \
	--var bosh_deployment="$BOSH_DEPLOYMENT" \
	--var bosh_lite_ip="$director_dns" \
	--vars-file="$SSL_YML" \
	--vars-env="$ENV_PREFIX_NAME" \
	--vars-store="$BOSH_FULL_VARS_FILE"

INFO 'Cloudfoundry VMs'
"$BOSH" vms
