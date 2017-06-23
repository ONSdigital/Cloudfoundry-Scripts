#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"
. "$BASE_DIR/common-cf.sh"
. "$BASE_DIR/bosh-env.sh"

eval export `prefix_vars "$DEPLOYMENT_FOLDER/bosh-config.sh"`
eval export `prefix_vars "$DEPLOYMENT_FOLDER/outputs.sh"`
eval export `prefix_vars "$DEPLOYMENT_FOLDER/passwords.sh"`
eval export `prefix_vars "$DEPLOYMENT_FOLDER/cf-credentials-admin.sh"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"
export BOSH_CA_CERT

DB_NAME="${1:-rds_broker}"
BROKER_NAME="${2:-rds-broker}"
CF_ORG="${3:-$organisation}"

RDS_BROKER_USER='rds_broker_user'
GOLANG_VERSION='1.8'
RDS_BROKER_FOLDER="$TMP_DIRECTORY/$BROKER_NAME"
RDS_BROKER_GIT_URL='https://github.com/cloudfoundry-community/rds-broker.git'

SERVICE_NAME='RDS'

[ -d "$TMP_DIRECTORY" ] || mkdir -p "$TMP_DIRECTORY"
[ -d "$RDS_BROKER_FOLDER" ] && rm -rf "$RDS_BROKER_FOLDER"

RDS_BROKER_PASSWORD="`generate_password`"
# Should be a multiple of something, probably 32, 16 or 8
RDS_BROKER_ENC_KEY="`generate_password 32`"

if "$CF" service-brokers | grep -Eq "^$SERVICE_NAME\s*http"; then
	[ -n "$IGNORE_EXISTING" ] && LOG_LEVEL='WARN' || LOG_LEVEL='FATAL'
	
	$LOG_LEVEL "Service broker '$SERVICE_NAME' exists"

	exit 0
fi

INFO 'Cloning Git RDS repository'
git clone "$RDS_BROKER_GIT_URL" "$RDS_BROKER_FOLDER"

INFO 'Creating RDS Broker Manifest'
cat >"$RDS_BROKER_FOLDER/manifest.yml" <<EOF
---
applications:
- name: "$BROKER_NAME"
  memory: 256M
  env:
    GOVERSION: go$GOLANG_VERSION
    # Should we create a special user just for this?
    AUTH_USER: $RDS_BROKER_USER
    AUTH_PASS: $RDS_BROKER_PASSWORD
    DB_URL: $rds_address
    DB_PORT: $rds_port
    DB_NAME: $DB_NAME
    DB_USER: $rds_username
    DB_PASS: $rds_password
    DB_TYPE: postgres
    #DB_SSLMODE:''
    ENC_KEY: $RDS_BROKER_ENC_KEY
    AWS_REGION: $aws_region
    AWS_ACCESS_KEY_ID: $rds_broker_access_key_id
    AWS_SECRET_ACCESS_KEY: $rds_broker_access_key
    INSTANCE_TAGS: [ 'name','$deployment_name-Broker-Database' ]
    AWS_SEC_GROUP: $rds_security_group
    AWS_DB_SUBNET_GROUP: $rds_subnet_group
EOF

if [ -f "$CONFIG_DIRECTORY/$SERVICE_NAME/catalog.yaml" ]; then
	cp -f "$CONFIG_DIRECTORY/$SERVICE_NAME/catalog.yaml" "$RDS_BROKER_FOLDER/catalog.yaml"
fi

INFO "Ensuring space exists: $SERVICES_SPACE"
"$BASE_DIR/setup_cf-orgspace.sh" "$DEPLOYMENT_NAME" "$ORG_NAME" "$SERVICES_SPACE"

INFO 'Creating inital RDS database'
WARN "This won't work when we have an external RDS database backing CF - we'll need to install psql locally and connect to the RDS Postgres instance"
"$BASE_DIR/bosh-ssh.sh" "$DEPLOYMENT_NAME" postgres <<EOF
export PGPASSWORD="$rds_password";
PSQL="\`find -L /var/vcap/packages -name psql | sort -n | tail -n1\`";
"\$PSQL" -h$rds_address -U$rds_username -c "CREATE DATABASE $DB_NAME" || :;
exit
EOF

cd "$RDS_BROKER_FOLDER"

INFO "Pushing $BROKER_NAME broker to Cloudfoundry"
"$BASE_DIR/cf_push.sh" "$DEPLOYMENT_NAME" "$BROKER_NAME" "$ORG_NAME" "$SERVICES_SPACE"

BROKER_URL="`cf_app_url \"$BROKER_NAME\"`"

"$BASE_DIR/setup_cf-service-broker.sh" "$DEPLOYMENT_NAME" "$SERVICE_NAME" "$RDS_BROKER_USER" "$RDS_BROKER_PASSWORD" "https://$BROKER_URL"
