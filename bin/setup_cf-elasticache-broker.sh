#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/common-cf.sh"
. "$BASE_DIR/bosh-env.sh"

eval export `prefix_vars "$DEPLOYMENT_FOLDER/outputs.sh"`
eval export `prefix_vars "$DEPLOYMENT_FOLDER/passwords.sh"`
eval export `prefix_vars "$DEPLOYMENT_FOLDER/cf-credentials-admin.sh"`

BROKER_NAME="${1:-elasticache-broker}"
BROKER_FOLDER="$TMP_DIRECTORY/$BROKER_NAME"
BROKER_GIT_URL='https://github.com/cloudfoundry-community/elasticache-broker'

BROKER_USERNAME='elasticache-broker'
BROKER_PASSWORD="`generate_password`"

GOLANG_VERSION='1.6.3'

[ -d "$TMP_DIRECTORY" ] || mkdir -p "$TMP_DIRECTORY"
[ -d "$BROKER_FOLDER" ] && rm -rf "$BROKER_FOLDER"

if "$CF" service-brokers | grep -Eq "^$BROKER_NAME\s*http"; then
	[ -n "$IGNORE_EXISTING" ] && LOG_LEVEL='WARN' || LOG_LEVEL='FATAL'
	
	$LOG_LEVEL "Service broker '$BROKER_NAME' exists"

	exit 0
fi

INFO 'Cloning Git ElastiCache repository'
git clone "$BROKER_GIT_URL" "$BROKER_FOLDER"

INFO 'Creating ElastiCache Broker Manifest'
cat >"$BROKER_FOLDER/manifest.yml" <<EOF
---
applications:
  - name: elasticache-broker
    memory: 256M
    disk_quota: 256M
    env:
      GOVERSION: go$GOLANG_VERSION
      AWS_ACCESS_KEY_ID: $elasti_cache_broker_access_key_id
      AWS_SECRET_ACCESS_KEY: $elasti_cache_broker_access_key
      GO15VENDOREXPERIMENT: 0
EOF

[ -f "$CONFIG_DIRECTORY/$BROKER_NAME/config.json" ] && JSON_CONFIG="$CONFIG_DIRECTORY/$BROKER_NAME/config.json" || JSON_CONFIG="$BROKER_FOLDER/config-sample.json"

INFO 'Adjusting ElastiCache configuration'
sed -re "s/(\"username\"): \"[^\"]+\"/\1: \"$BROKER_USERNAME\"/g" \
	-e "s/(\"password\"): \"[^\"]+\"/\1: \"$BROKER_PASSWORD\"/g" \
	-e "s/(\"region\"): \"[^\"]+\"/\1: \"$aws_region\"/g" \
	-e "s/(\"cache_subnet_group_name\"): \"[^\"]+\"/\1: \"$elasti_cache_subnet_group\"/g" \
	-e "s/\"default\"/\"$elasti_cache_security_group\"/g" \
	-e "s/(\"name\"): \"awselasticache-redis\"/\1: \"$BROKER_NAME\"/g" \
	"$JSON_CONFIG" >"$BROKER_FOLDER/config.json"

INFO "Ensuring space exists: $SERVICES_SPACE"
"$BASE_DIR/setup_cf-orgspace.sh" "$DEPLOYMENT_NAME" "$ORG_NAME" "$SERVICES_SPACE"

cd "$BROKER_FOLDER"

INFO "Pushing $BROKER_NAME broker to Cloudfoundry"
"$BASE_DIR/cf_push.sh" "$DEPLOYMENT_NAME" "$BROKER_NAME" "$ORG_NAME" "$SERVICES_SPACE"

BROKER_URL="`cf_app_url \"$BROKER_NAME\"`"

"$BASE_DIR/setup_cf-service-broker.sh" "$DEPLOYMENT_NAME" "$BROKER_NAME" "$BROKER_USERNAME" "$BROKER_PASSWORD" "https://$BROKER_URL"