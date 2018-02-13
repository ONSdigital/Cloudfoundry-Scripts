#!/bin/sh
#
# Parameters:
#	Deployment Name
#	[Broker Name]
#
# Variables:
#	IGNORE_EXISTING=[true|false]
#
# Requires:
#	common.sh
#	bosh-env.sh
#

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="$1"
BROKER_NAME="${2:-elasticache}"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/bosh-env.sh"

INFO 'Loading CF credentials'
. "$CF_CREDENTIALS"

installed_bin cf

BROKER_DIR="$TMP_DIR/$BROKER_NAME"
BROKER_GIT_URL='https://github.com/cloudfoundry-community/elasticache-broker'

BROKER_USERNAME='elasticache-broker'
BROKER_PASSWORD="`generate_password`"

GOLANG_VERSION='1.6.4'

[ -d "$TMP_DIR" ] || mkdir -p "$TMP_DIR"
[ -d "$BROKER_DIR" ] && rm -rf "$BROKER_DIR"

if "$CF_CLI" service-brokers | grep -Eq "^$BROKER_NAME\s*http"; then
	[ -n "$IGNORE_EXISTING" ] && LOG_LEVEL='WARN' || LOG_LEVEL='FATAL'

	$LOG_LEVEL "Service broker '$BROKER_NAME' exists"

	exit 0
fi

INFO 'Cloning Git ElastiCache repository'
git clone "$BROKER_GIT_URL" "$BROKER_DIR"

INFO 'Creating ElastiCache Broker Manifest'
cat >"$BROKER_DIR/manifest.yml" <<EOF
---
applications:
  - name: elasticache-broker
    memory: 256M
    disk_quota: 256M
    env:
      GOVERSION: go$GOLANG_VERSION
      AWS_ACCESS_KEY_ID: $elasti_cache_broker_access_key_id
      AWS_SECRET_ACCESS_KEY: $elasti_cache_broker_secret_access_key
      GO15VENDOREXPERIMENT: 0
EOF

[ -f "$BROKER_CONFIG_DIR/$BROKER_NAME/config.json" ] && JSON_CONFIG="$BROKER_CONFIG_DIR/$BROKER_NAME/config.json" || JSON_CONFIG="$BROKER_DIR/config-sample.json"

INFO 'Adjusting ElastiCache configuration'
sed $SED_EXTENDED -e "s/(\"username\"): \"[^\"]+\"/\1: \"$BROKER_USERNAME\"/g" \
	-e "s/(\"password\"): \"[^\"]+\"/\1: \"$BROKER_PASSWORD\"/g" \
	-e "s/(\"region\"): \"[^\"]+\"/\1: \"$aws_region\"/g" \
	-e "s/(\"cache_subnet_group_name\"): \"[^\"]+\"/\1: \"$elasti_cache_subnet_group\"/g" \
	-e "s/\"default\"/\"$elasti_cache_security_group\"/g" \
	-e "s/(\"name\"): \"awselasticache-redis\"/\1: \"$BROKER_NAME\"/g" \
	"$JSON_CONFIG" >"$BROKER_DIR/config.json"

INFO "Ensuring space exists: $SERVICES_SPACE"
"$BASE_DIR/setup_cf-orgspace.sh" "$DEPLOYMENT_NAME" "$ORG_NAME" "$SERVICES_SPACE"

cd "$BROKER_DIR"

INFO "Pushing $BROKER_NAME broker to Cloudfoundry"
"$BASE_DIR/cf_push.sh" "$DEPLOYMENT_NAME" "$BROKER_NAME" "$ORG_NAME" "$SERVICES_SPACE"

BROKER_URL="`cf_app_url \"$BROKER_NAME\"`"

"$BASE_DIR/setup_cf-service-broker.sh" "$DEPLOYMENT_NAME" "$BROKER_NAME" "$BROKER_USERNAME" "$BROKER_PASSWORD" "https://$BROKER_URL"
