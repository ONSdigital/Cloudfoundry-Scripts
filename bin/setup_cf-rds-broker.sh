#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

DEFAULT_RDS_BROKER_DB_NAME="${RDS_BROKER_DB_NAME:-rds_broker}"
DEFAULT_RDS_BROKER_NAME="${RDS_BROKER_NAME:-rds_broker}"

DEPLOYMENT_NAME="$1"
RDS_BROKER_DB_NAME="${2:-$DEFAULT_RDS_BROKER_DB_NAME}"
RDS_BROKER_NAME="${3:-$DEFAULT_RDS_BROKER_NAME}"
CF_ORG="${4:-$organisation}"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/bosh-env.sh"

installed_bin cf

eval export `prefix_vars "$BOSH_DIRECTOR_CONFIG"`
eval export `prefix_vars "$PASSWORD_CONFIG_FILE"`
eval export `prefix_vars "$CF_CREDENTIALS"`
eval export `prefix_vars "$BOSH_SSH_CONFIG"`

[ -f "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh" ] && eval export `prefix_vars "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
export BOSH_CA_CERT

RDS_BROKER_USER="${RDS_BROKER_USER:-rds_broker_user}"
GOLANG_VERSION='1.8'
RDS_BROKER_DIR="$TMP_DIR/$RDS_BROKER_NAME"
RDS_BROKER_GIT_URL='https://github.com/cloudfoundry-community/rds-broker.git'

SERVICE_NAME='rds'

[ -d "$TMP_DIR" ] || mkdir -p "$TMP_DIR"
[ -d "$RDS_BROKER_DIR" ] && rm -rf "$RDS_BROKER_DIR"

RDS_BROKER_PASSWORD="${RDS_BROKER_PASSWORD:-`generate_password`}"
# Should be a multiple of something, probably 32, 16 or 8
RDS_BROKER_ENC_KEY="${RDS_BROKER_ENC_KEY:-`generate_password 32`}"

if "$CF" service-brokers | grep -Eq "^$SERVICE_NAME\s*http"; then
	[ -n "$IGNORE_EXISTING" ] && LOG_LEVEL='WARN' || LOG_LEVEL='FATAL'
	
	$LOG_LEVEL "Service broker '$SERVICE_NAME' exists"

	exit 0
fi

INFO 'Cloning Git RDS repository'
git clone "$RDS_BROKER_GIT_URL" "$RDS_BROKER_DIR"

INFO 'Creating RDS Broker Manifest'
cat >"$RDS_BROKER_DIR/manifest.yml" <<EOF
---
applications:
- name: $RDS_BROKER_NAME
  memory: 256M
  env:
    GOVERSION: go$GOLANG_VERSION
    # Should we create a special user just for this?
    AUTH_USER: $RDS_BROKER_USER
    AUTH_PASS: $RDS_BROKER_PASSWORD
    DB_URL: $rds_apps_instance_dns
    DB_PORT: $rds_apps_instance_port
    DB_NAME: $RDS_BROKER_DB_NAME
    DB_USER: $rds_apps_instance_username
    DB_PASS: $rds_apps_instance_password
    DB_TYPE: postgres
    #DB_SSLMODE:''
    ENC_KEY: $RDS_BROKER_ENC_KEY
    AWS_REGION: $aws_region
    AWS_ACCESS_KEY_ID: $rds_broker_access_key_id
    AWS_SECRET_ACCESS_KEY: $rds_broker_secret_access_key
    INSTANCE_TAGS: [ 'name','$deployment_name-Broker-Database' ]
    AWS_SEC_GROUP: $rds_security_group
    AWS_DB_SUBNET_GROUP: $rds_subnet_group
EOF

if [ -f "$BROKER_CONFIG_DIR/$SERVICE_NAME/catalog.yaml" ]; then
	cp -f "$BROKER_CONFIG_DIR/$SERVICE_NAME/catalog.yaml" "$RDS_BROKER_DIR/catalog.yaml"
fi

INFO "Ensuring space exists: $SERVICES_SPACE"
"$BASE_DIR/setup_cf-orgspace.sh" "$DEPLOYMENT_NAME" "$ORG_NAME" "$SERVICES_SPACE"

cat >"$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh.new" <<EOF
# RDS
RDS_BROKER_DB_NAME="$RDS_BROKER_DB_NAME"
RDS_BROKER_DB_ADDRESS="$rds_apps_instance_dns"
RDS_BROKER_DB_USERNAME="$rds_apps_instance_username"
RDS_BROKER_DB_PASSWORD="$rds_apps_instance_password"
# Broker configuration
RDS_BROKER_NAME="$RDS_BROKER_NAME"
RDS_BROKER_USER="$RDS_BROKER_USER"
RDS_BROKER_PASSWORD="$RDS_BROKER_PASSWORD"
RDS_BROKER_ENC_KEY="$RDS_BROKER_ENC_KEY"
EOF

if [ ! -f "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh" ]; then
	mv "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh.new" "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh"

elif diff -q "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh" "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh.new"; then
	rm -f "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh"

	INFO "Updating '$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh'"
	mv "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh.new" "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh"
else
	INFO "Not updating '$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh'"
	rm -f "$DEPLOYMENT_DIR/cf-broker-rds-credentials.sh"
fi

cd "$RDS_BROKER_DIR"

INFO "Pushing $BROKER_NAME broker to Cloudfoundry"
"$BASE_DIR/cf_push.sh" "$DEPLOYMENT_NAME" "$RDS_BROKER_NAME" "$ORG_NAME" "$SERVICES_SPACE"

BROKER_URL="`cf_app_url \"$RDS_BROKER_NAME\"`"

"$BASE_DIR/setup_cf-service-broker.sh" "$DEPLOYMENT_NAME" "$SERVICE_NAME" "$RDS_BROKER_USER" "$RDS_BROKER_PASSWORD" "https://$BROKER_URL"
