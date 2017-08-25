#!/bin/sh
#
# Generate SSL CAs and keypairs
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

EXTERNAL_CA_NAME="${1:-$EXTERNAL_CA_NAME}"
INTERNAL_CA_NAME="${2:-$INTERNAL_CA_NAME}"
OUTPUT_YML="${3:-$OUTPUT_YML}"
ORGANISATION="${4:-$ORGANISATION}"

APPS_DOMAIN="${5:-apps.$EXTERNAL_CA_NAME}"
SYSTEM_DOMAIN="${6:-system.$EXTERNAL_CA_NAME}"
SERVICE_DOMAIN="${7:-service.$INTERNAL_CA_NAME}"
EXTERNAL_DOMAIN="${8:-$EXTERNAL_CA_NAME}"

ONLY_MISSING="${ONLY_MISSING:-true}"

# Append $EXTERNAL_CA_NAME
EXTERNAL_SSL_NAMES='jwt'

# Append $EXTERNAL_CA_NAME, generate public key and public key fingerprint
EXTERNAL_SSH_NAMES='cf-ssh'

# Append $SERVICE_DOMAIN
INTERNAL_SERVICE_SSL_NAMES='cloud-controller-ng uaa blobstore'

# Append $SERVICE_DOMAIN and prefix vars with consul_
INTERNAL_CONSUL_SSL_NAMES='server.dc1 agent.dc1'

# Unqualified names
INTERNAL_SIMPLE_SSL_NAMES='doppler cc_trafficcontroller trafficcontroller metron syslogdrainbinder statsdinjector tps_watcher cc_uploader_cc cc_uploader_mutual router'

# Passed through to $CA_TOOL
export EXTENDED_CRITICAL=
export ORGANISATION

[ -z "$OUTPUT_YML"  ] && FATAL 'OUTPUT_YML not supplied'
[ -z "$EXTERNAL_CA_NAME" ] && FATAL 'EXTERNAL_CA_NAME not supplied'
[ -z "$INTERNAL_CA_NAME" ] && FATAL 'INTERNAL_CA_NAME not supplied'

generate_vars_yml(){
	local var_file="$1"
	local keypair_file="$2"
	local variable_name="$3"
	local variable_prefix="$4"
	local variable_suffix="$5"

	[ -z "$var_file" ] && FATAL 'No YML fiename supplied'
	[ -z "$keypair_file" ] && FATAL 'No keypair filename supplied'
	[ x"$variable_name" = x"NONE" ] && unset variable_name
	[ x"$variable_prefix" = x"NONE" ] && unset variable_prefix

	if [ -f "$keypair_file" ]; then
		local keypair_files="$keypair_file"
	else
		local keypair_files="$keypair_file.crt $keypair_file.key"

		[ -f "$keypair_file.crt" ] || FATAL "Certificate does not exist: $keypair_file.crt"
		[ -f "$keypair_file.key" ] || FATAL "Key does not exist: $keypair_file.key"
	fi

	for _k in $keypair_files; do
		var_name="$variable_name"
		var_suffix="$variable_suffix"

		[ -z "$var_name" ] && var_name="`echo $_k | sed $SED_EXTENDED -e "s,^([^/]*/)*([^./]+)(\.[^/]+)$,\2,g" -e 's/-/_/g'`"
		[ x"$var_suffix" != x"NONE" -a -z "$var_suffix" ] && local var_suffix="`echo $_k | sed $SED_EXTENDED -e 's/^.*.(ce?rt|key)$/_\1/g'`"

		[ -z "$var_name" ] && FATAL "Unable to determine variable name from $_k and nothing was supplied"
		[ x"$var_suffix" != x"NONE" -a -z "$var_suffix" ] && FATAL "Unable to determine variable suffix from $_k and nothing was supplied"

		[ x"$var_suffix" = x"NONE" ] && unset var_suffix

		local length="`wc -l \"$_k\" | awk '{print $1}'`"

		[ -f "$var_file" ] || echo --- >"$var_file"

		if [ 0$length -gt 1 ]; then
			sed $SED_EXTENDED -e 's/^(.*)$/\L\1/g' >>"$var_file" <<EOF
$variable_prefix$var_name$var_suffix: |
EOF
			sed $SED_EXTENDED -e 's/^/  /g' "$_k" >>"$var_file"
		else
			sed $SED_EXTENDED -e 's/^(.*)$/\L\1/g' >>"$var_file" <<EOF
$variable_prefix$var_name$var_suffix: `cat "$_k"`
EOF
		fi

		unset var_name var_suffix
	done
}

# Generate CAs
for _i in $EXTERNAL_CA_NAME $INTERNAL_CA_NAME; do
	[ x"$ONLY_MISSING" = x"true" -a -f "$_i/ca/$_i.crt" ] && continue

	"$CA_TOOL" --new-ca --ca-name "$_i" --not-trusted
done

[ x"$ONLY_MISSING" = x"true" -a -f "$INTERNAL_CA_NAME/ca/$INTERNAL_CA_NAME.crt" ] || generate_vars_yml "$OUTPUT_YML" "$INTERNAL_CA_NAME/ca/$INTERNAL_CA_NAME.crt" internal_ca
[ x"$ONLY_MISSING" = x"true" -a -f "$EXTERNAL_CA_NAME/ca/$EXTERNAL_CA_NAME.crt" ] || generate_vars_yml "$OUTPUT_YML" "$EXTERNAL_CA_NAME/ca/$EXTERNAL_CA_NAME.crt" external_ca

if [ x"$ONLY_MISSING" = x"false" -o ! -f "$EXTERNAL_CA_NAME/client/ha-proxy.$SYSTEM_DOMAIN.crt" ]; then
	# Public facing SSL
	"$CA_TOOL" --ca-name "$EXTERNAL_CA_NAME" --name "ha-proxy.$SYSTEM_DOMAIN" -s "DNS:*.$APPS_DOMAIN" -s "DNS:*.$SYSTEM_DOMAIN"
	generate_vars_yml "$OUTPUT_YML" "$EXTERNAL_CA_NAME/client/ha-proxy.$SYSTEM_DOMAIN"
fi

if [ x"$ONLY_MISSING" = x"false" -o ! -f "$EXTERNAL_CA_NAME/client/director.$EXTERNAL_DOMAIN.crt" ]; then
	"$CA_TOOL" --ca-name "$EXTERNAL_CA_NAME" --name "director.$EXTERNAL_DOMAIN" -s "DNS:director.$EXTERNAL_DOMAIN"
	generate_vars_yml "$OUTPUT_YML" "$EXTERNAL_CA_NAME/client/director.$EXTERNAL_DOMAIN"
fi

if [ x"$ONLY_MISSING" = x"false" -o ! -f "$INTERNAL_CA_NAME/client/cf-etcd.$SERVICE_DOMAIN.crt" ]; then
	"$CA_TOOL" --ca-name "$INTERNAL_CA_NAME" --name "cf-etcd.$SERVICE_DOMAIN" -s "DNS:cf-etcd.$SERVICE_DOMAIN" -s "DNS:*.cf-etcd.$SERVICE_DOMAIN"
	"$CA_TOOL" --ca-name "$INTERNAL_CA_NAME" --name 'cf-etcd-client' -s "DNS:cf-etcd-client.$SERVICE_DOMAIN"
	generate_vars_yml "$OUTPUT_YML" "$INTERNAL_CA_NAME/client/cf-etcd.$SERVICE_DOMAIN.crt" NONE NONE _server_crt
	generate_vars_yml "$OUTPUT_YML" "$INTERNAL_CA_NAME/client/cf-etcd.$SERVICE_DOMAIN.key" NONE NONE _server_key
	generate_vars_yml "$OUTPUT_YML" "$INTERNAL_CA_NAME/client/cf-etcd-client"
fi

for i in $EXTERNAL_SSL_NAMES; do
	[ x"$ONLY_MISSING" = x"true" -f "$EXTERNAL_CA_NAME/client/$i.$EXTERNAL_CA_NAME.crt" ] && continue

	"$CA_TOOL" --ca-name "$EXTERNAL_CA_NAME" --name "$i.$EXTERNAL_CA_NAME"

	generate_vars_yml "$OUTPUT_YML" "$EXTERNAL_CA_NAME/client/$i.$EXTERNAL_CA_NAME"
done

for i in $EXTERNAL_SSH_NAMES; do
	[ x"$ONLY_MISSING" = x"true" -f "$EXTERNAL_CA_NAME/client/$i.$EXTERNAL_CA_NAME.crt" ] && continue

	"$CA_TOOL" --ca-name "$EXTERNAL_CA_NAME" --name "$i.$EXTERNAL_CA_NAME" --generate-public-key --generate-public-key-ssh-fingerprint

	generate_vars_yml "$OUTPUT_YML" "$EXTERNAL_CA_NAME/client/$i.$EXTERNAL_CA_NAME.key" ssh_host_key NONE NONE
	generate_vars_yml "$OUTPUT_YML" "$EXTERNAL_CA_NAME/client/$i.$EXTERNAL_CA_NAME.pub" ssh_host_key_public_key NONE NONE
	generate_vars_yml "$OUTPUT_YML" "$EXTERNAL_CA_NAME/client/$i.$EXTERNAL_CA_NAME.ssh-fingerprint" ssh_host_key_fingerprint NONE NONE
done

for i in $INTERNAL_CONSUL_SSL_NAMES; do
	[ x"$ONLY_MISSING" = x"true" -f "$INTERNAL_CA_NAME/client/$i.$INTERNAL_CA_NAME.crt" ] && continue

	"$CA_TOOL" --ca-name "$INTERNAL_CA_NAME" --name "$i.$INTERNAL_CA_NAME"

	generate_vars_yml "$OUTPUT_YML" "$INTERNAL_CA_NAME/client/$i.$INTERNAL_CA_NAME" NONE consul_
done

for i in $INTERNAL_SIMPLE_SSL_NAMES; do
	[ x"$ONLY_MISSING" = x"true" -f "$EXTERNAL_CA_NAME/client/$i.crt" ] && continue

	"$CA_TOOL" --ca-name "$INTERNAL_CA_NAME" --name "$i"

	generate_vars_yml "$OUTPUT_YML" "$INTERNAL_CA_NAME/client/$i"
done

for i in $INTERNAL_FULL_SSL_NAMES; do
	[ x"$ONLY_MISSING" = x"true" -f "$INTERNAL_CA_NAME/client/$i.$INTERNAL_CA_NAME.crt" ] && continue

	"$CA_TOOL" --ca-name "$INTERNAL_CA_NAME" --name "$i.$INTERNAL_CA_NAME"

	generate_vars_yml "$OUTPUT_YML" "$INTERNAL_CA_NAME/client/$i.$INTERNAL_CA_NAME"
done

for i in $INTERNAL_SERVICE_SSL_NAMES; do
	[ x"$ONLY_MISSING" = x"true" -f "$INTERNAL_CA_NAME/client/$i.$SERVICE_DOMAIN.crt" ] && continue

	"$CA_TOOL" --ca-name "$INTERNAL_CA_NAME" --name "$i.$SERVICE_DOMAIN"

	generate_vars_yml "$OUTPUT_YML" "$INTERNAL_CA_NAME/client/$i.$SERVICE_DOMAIN"
done
