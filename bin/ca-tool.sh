#!/bin/sh
#
# Simple-ish script to generate/update CA and create/update signed key pairs or
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

# Defaults
KEY_SIZE="${KEY_SIZE:-4096}"
HASH_TYPE="${HASH_TYPE:-sha512}"
ORGANISTAION="${ORGANISTAION:-Organisation}"
VALID_DAYS="${VALID_DAYS:-3650}"

# To work around OpenSSL complaining/dying when there is no $ENV::SAN variable even when its not used
SAN="IGNORED"

# We allow unsetting of this, if required
TRUST_OPT="${TRUST_OPT:--trustout}"
# Trailing comma is critical
BASIC_USAGE="${BASIC_USAGE:-critical,}"
EXTENDED_USAGE="${EXTENDED_USAGE:-critical,}"

for i in $@; do
	case "$i" in
		--new-ca|-N)
			NEW_CA=1
			shift
			;;
		--ca-name|-c)
			CA_NAME="$2"
			shift 2
			;;
		--update-ca)
			UPDATE_CA=1
			shift
			;;
		--name|-n)
			NAME="$2"
			shift 2
			;;
		--update-name)
			UPDATE_NAME=1
			shift
			;;
		--key-size|-k)
			KEY_SIZE="$2"
			shift 2
			;;
		--not-basic-critical|-b)
			# OpenSSL is happy if these are defined, but empty
			BASIC_USAGE=
			;;
		--not-extended-critical|-c)
			EXTENDED_USAGE=
			;;
		--organisation|-o)
			shift

			for j in $@; do
				grep -Eq "^-" <<EOF && break
$j
EOF
				[ -z "$ORGANISTAION" ] && ORGANISTAION="$j" || ORGANISTAION="$ORGANISTAION $j"

				shift
			done
			;;
		--subject-alt-names|-s)
			shift

			for j in $@; do
				grep -Eq "^-" <<EOF && break
$j
EOF
				[ x"$SAN" = x"IGNORED" ] && SAN="$j" || SAN="$SAN,$j"

				shift
			done

			;;
		--not-trusted|-t)
			shift

			# Bosh doesn't believe a cert starting with 'BEGIN TRUSTED CERTIFICATE' is a valid
			unset TRUST_OPT
			;;
		--generate-public-key|-p)
			shift
			GENERATE_PUBLIC_KEY=1
			;;
		--generate-public-key-ssh-fingerprint|-f)
			shift
			GENERATE_PUBLIC_KEY_SSH_FINGER_PRINT=1
			;;
		-*)
			FATAL "Unknown configuration option $i"
			;;
	esac
done

[ -z "$CA_NAME" ] && FATAL No CA name provided

# OpenSSL loads its config from this var
export OPENSSL_CONF="$PWD/$CA_NAME/openssl-$CA_NAME.cnf"

# Make SAN available to openssl - without this it'll complain and die
export SAN BASIC_USAGE EXTENDED_CRITICAL

if [ -n "$NEW_CA" ]; then
	[ -d "$CA_NAME" ] && FATAL "Existing CA directory exists $PWD/$CA_NAME"

	INFO "Generating new CA $CA_NAME"
	INFO "Creating directory layout"
	mkdir -p "$CA_NAME/client" "$CA_NAME/certs" "$CA_NAME/ca"

	INFO "Initialising serial.txt"
	echo 01 >"$CA_NAME/serial.txt"
fi

[ -z "$NEW_CA" -a ! -f "$OPENSSL_CONF" ] && FATAL "No OpenSSL configuration available: $OPENSSL_CONF"

[ -d "$CA_NAME" ] || FATAL "CA directory does not exist: $PWD/$CA_NAME"

cd "$CA_NAME"

if [ -n "$NEW_CA" ]; then
	INFO "Generating openssl configuration"
	cat >"$OPENSSL_CONF" <<EOF
# Default vars
CA_NAME=$CA_NAME
KEY_SIZE=$KEY_SIZE
HASH_TYPE=$HASH_TYPE
VALID_DAYS=$VALID_DAYS
ORGANISTAION=EMPTY
SAN=DNS:EMPTY
BASIC_CRITICAL=$BASIC_USAGE
EXTENDED_CRITICAL=$EXTENDED_CRITICAL
DIR=./
EOF
	# We're lazy and do this to avoid having to escape all of the vars
	cat >>"$OPENSSL_CONF" <<'EOF'
#
[default]
# This is ignored by openssl 'req'
default_days			= $ENV::VALID_DAYS
default_md			= $ENV::HASH_TYPE
default_bits			= $ENV::KEY_SIZE
#
policy				= policy_default
distinguished_name		= req_distinguished_name

# Directories
# $ENV::var will not work with LibreSSL
dir				= $ENV::DIR
serial				= $dir/serial.txt

[x509v3_ca]
subjectKeyIdentifier=hash
basicConstraints		= critical,CA:true
authorityKeyIdentifier		= keyid,issuer
extendedKeyUsage		= critical,codeSigning,serverAuth,clientAuth
keyUsage			= nonRepudiation,digitalSignature,keyEncipherment,dataEncipherment,keyCertSign,cRLSign

[x509v3]
subjectKeyIdentifier=hash
# $ENV::var will not work with LibreSSL
basicConstraints		= ${ENV::BASIC_CRITICAL}CA:FALSE
authorityKeyIdentifier		= keyid,issuer
# $ENV::var will not work with LibreSSL
extendedKeyUsage		= ${ENV::EXTENDED_CRITICAL}codeSigning,serverAuth,clientAuth
keyUsage			= nonRepudiation,digitalSignature,keyEncipherment,dataEncipherment

[x509v3_san]
subjectKeyIdentifier=hash
basicConstraints		= $x509v3::basicConstraints
authorityKeyIdentifier		= $x509v3::authorityKeyIdentifier
extendedKeyUsage		= $x509v3::extendedKeyUsage
keyUsage			= $x509v3::keyUsage
# $ENV::var will not work with LibreSSL
subjectAltName			= $ENV::SAN

[ca_default]

[policy_default]
[req_distinguished_name]
EOF

	INFO "Generating ca/$CA_NAME.key"
	openssl genrsa -out "ca/$CA_NAME.key" "$KEY_SIZE"
fi

# Key size has to be specified on the command line as 'default_bits' is ignored
[ -z "$KEY_SIZE" ] && eval KEY_SIZE="`awk -F' ?= ?' '/^KEY_SIZE/{print $2}' \"$OPENSSL_CONF\"`"
[ -z "$KEY_SIZE" ] && FATAL "Unable to determine key size"

[ -f "ca/$CA_NAME.key" ] || FATAL "CA key does not exist: ca/$CA_NAME.key"

if [ -n "$NEW_CA" -o -n "$UPDATE_CA" ]; then
	INFO "Generating $CA_NAME CA"
	openssl req -new -out "ca/$CA_NAME.csr" -key "ca/$CA_NAME.key" -subj "/CN=$CA_NAME/" -extensions x509v3_ca -days "$VALID_DAYS"
	# OPENSSL_CONF doesn't seem to work for x509
	openssl x509 $TRUST_OPT -req -in "ca/$CA_NAME.csr" -out "ca/$CA_NAME.crt" -signkey "ca/$CA_NAME.key" -CAserial serial.txt -extensions x509v3_ca \
		-extfile "$OPENSSL_CONF" -days "$VALID_DAYS"
fi

if [ -n "$NAME" ]; then
	if [ -z "$UPDATE_NAME" ]; then
		# If we have't got a key we generate one
		INFO "Generating $NAME key"
		openssl genrsa -out "client/$NAME.key" "$KEY_SIZE"
	fi

	# Have we been given a Subject Alt Name?
	[ x"$SAN" != x"IGNORED" ] && EXTENSIONS=x509v3_san || EXTENSIONS=x509v3

	# Generate CSR
	INFO "Generating $NAME CSR"
	openssl req -new -out "client/$NAME.csr" -key "client/$NAME.key" -extensions $EXTENSIONS -subj "/CN=$NAME/" -days "$VALID_DAYS"

	# Sign CSR
	INFO "Signing $NAME CSR"
	openssl x509 -req -in "client/$NAME.csr" -out "client/$NAME.crt" -CA "ca/$CA_NAME.crt" -CAkey "ca/$CA_NAME.key" -CAserial serial.txt -extensions $EXTENSIONS \
		-extfile "$OPENSSL_CONF" -days "$VALID_DAYS"

	# Generate file containing the metadata
	INFO "Generating $NAME metadata file"
	openssl x509 -text -noout -in "client/$NAME.crt" >"client/$NAME.txt"

	if [ -n "$GENERATE_PUBLIC_KEY" ]; then
		INFO "Generating $NAME public key"
		openssl x509 -in "client/$NAME.crt" -noout -pubkey >"client/$NAME.pub"

		if [ -n "$GENERATE_PUBLIC_KEY_SSH_FINGER_PRINT" ]; then
			INFO 'Computing SSH public key'
			ssh-keygen -i -m PKCS8 -f "client/$NAME.pub" >"client/$NAME.ssh-pub"

			INFO 'Computing SSH public key fingerprint'
			if ssh-keygen --help 2>&1 | grep -qE -- '-E fingerprint_hash'; then
				# We have a modern version of SSH
				ssh-keygen -E md5 -lf "client/$NAME.ssh-pub" | sed -re 's/^.*MD5:([^ ]+)( .*$)?$/\1/g' >"client/$NAME.ssh-fingerprint"
			else
				# We have an old version of SSH
				ssh-keygen -l -f "client/$NAME.ssh-pub" | awk '{print $2}' >"client/$NAME.ssh-fingerprint"
			fi
		fi
	fi
fi
