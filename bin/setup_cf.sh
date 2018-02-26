#!/bin/sh
#
# Setup Cloudfoundry after deployment.  This script is meant to be called with the various parameters already set
#
# Parameters:
#
# Variables:
#	[DEPLOYMENT_NAME]
#	[DONT_SKIP_SSL_VALIDATION]
#	SKIP_TESTS=[true|false]
#
# Requires:
#	common.sh
#	bosh-env.sh

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
#EMAIL_ADDRESS="${2:-NONE}"
ORG_NAME="${2:-$organisation}"
TEST_SPACE="${3:-Test}"
DONT_SKIP_SSL_VALIDATION="${4:-$DONT_SKIP_SSL_VALIDATION}"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/bosh-env.sh"

[ -z "$ORG_NAME" ] && ORG_NAME="$organisation"

# We don't want any sub-scripts to login
export NO_LOGIN=1

[ -z "$EMAIL_ADDRESS" ] && FATAL 'No email address has been supplied'
[ -n "$DONT_SKIP_SSL_VALIDATION" ] || CF_EXTRA_OPTS='--skip-ssl-validation'
[ -z "$ORG_NAME" ] && FATAL 'No organisation has been set'

findpath TEST_APPS "$BASE_DIR/../test-apps"

# Ensure we have CF available
installed_bin cf

# We may not always want to update the admin user
#[ x"$EMAIL_ADDRESS" != x"NONE" ] && "$BASE_DIR/setup_cf-admin.sh" "$DEPLOYMENT_NAME" cf_admin "$EMAIL_ADDRESS"

[ -f "$CF_CREDENTIALS" ] || FATAL "Cannot find CF admin credentials: $CF_CREDENTIALS. Has an admin user been created"

# Pull in newly generated credentials
INFO 'Loading CF credentials'
. "$CF_CREDENTIALS"

INFO "Setting API target as $api_dns"
"$CF_CLI" api "$api_dns" "$CF_EXTRA_OPTS"

INFO "Logging in as $CF_ADMIN_USERNAME"
"$CF_CLI" login -u "$CF_ADMIN_USERNAME" -p "$CF_ADMIN_PASSWORD" "$CF_EXTRA_OPTS" </dev/null

"$BASE_DIR/setup_cf-orgspace.sh" "$DEPLOYMENT_NAME" "$ORG_NAME" "$TEST_SPACE"

INFO 'Available buildpacks:'
# Sometimes we get a weird error, but upon next deployment the error doesn't occur...
# Server error, status code: 400, error code: 100001, message: The app is invalid: buildpack staticfile_buildpack is not valid public url or a known buildpack name
"$CF_CLI" buildpacks

if [ -z "$SKIP_TESTS" ]; then
	INFO 'Testing application deployment'
	for i in `ls "$TEST_APPS"`; do
		buildpack="`awk '/^ *buildpack:/{print $2}' "$TEST_APPS/$i/manifest.yml"`"

		if [ -n "$buildpack" ]; then
			"$CF_CLI" buildpacks | grep -q "^$buildpack" || FATAL "Buildpack '$buildpack' not available - please retry"
		fi

		cd "$TEST_APPS/$i"

		"$BASE_DIR/cf_push.sh" "$DEPLOYMENT_NAME" "$i" "$ORG_NAME" "$TEST_SPACE" "$TEST_APPS/$i"

		"$BASE_DIR/cf_delete.sh" "$DEPLOYMENT_NAME" "$i"

		cd -
	done
fi


if [ -n "$deploy_apps_rds_instance" -a x"$deploy_apps_rds_instance" != x"false" ]; then
	INFO 'Setting up RDS broker'
	IGNORE_EXISTING=1 "$BASE_DIR/setup_cf-rds-broker.sh" "$DEPLOYMENT_NAME"
fi

if [ -n "$create_elasti_cache_infrastructure" -a x"$create_elasti_cache_infrastructure" != x"false" ]; then
	INFO 'Setting up ElastiCache broker'
	IGNORE_EXISTING=1 "$BASE_DIR/setup_cf-elasticache-broker.sh" "$DEPLOYMENT_NAME" elasticache-broker
fi

if [ -d "local/security_groups" ]; then
	INFO 'Setting up Security Groups'

	for _g in common "$DEPLOYMENT_NAME"; do
		for _s in `ls "local/security_groups/$_g"`; do
			group_name="`echo $security_group | sed $SED_EXTENDED -e 's/\.json$//g'`"
			INFO "... $group_name"
	
			"$CF_CLI" create-security-group "$group_name" "local/security_groups/$_g/$_s"
		done
	done
fi
