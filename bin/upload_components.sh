#!/bin/sh
#
# https://bosh.io/releases
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

#
# See https://bosh.io/releases/github.com/cloudfoundry/cf-release and check 'Compatible Releases and Stemcells' for versions
#
# https://bosh.io/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent
BOSH_STEMCELL_URL="${1:-$BOSH_STEMCELL_URL}"

# https://bosh.io/releases/github.com/cloudfoundry/cf-release
RELEASE_CF_VERSION="${2:-$RELEASE_CF_VERSION}"
# https://bosh.io/releases/github.com/cloudfoundry/diego-release
RELEASE_DIEGO_VERSION="${3:-$RELEASE_DIEGO_VERSION}"
# https://bosh.io/releases/github.com/cloudfoundry/garden-runc-release
RELEASE_GARDEN_RUNC_VERSION="${4:-$RELEASE_GARDEN_RUNC_VERSION}"
# https://bosh.io/releases/github.com/cloudfoundry/cflinuxfs2-release
RELEASE_CFLINUXFS2_ROOTFS_VERSION="${5:-$RELEASE_CFLINUXFS2_ROOTFS_VERSION}"
# https://bosh.io/releases/github.com/pivotal-cf/cf-rabbitmq-release
RELEASE_CF_RABBITMQ_VERSION="${6:-$RELEASE_CF_RABBITMQ_VERSION}"
# Release v228 seems to be missing the rabbitmq-broker and its not, yet, available on https://bosh.io/d/github.com/pivotal-cf/cf-rabbitmq-broker
RELEASE_CF_RABBITMQ_VERSION="226.0.0"
# Stemcells
BOSH_STEMCELL_URL="${BOSH_STEMCELL_URL:-https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent}"

# Releases
RELEASE_CF_URL="${RELEASE_CF_URL:-https://bosh.io/d/github.com/cloudfoundry/cf-release}"
RELEASE_DIEGO_URL="${RELEASE_DIEGO_URL:-https://bosh.io/d/github.com/cloudfoundry/diego-release}"
RELEASE_GARDEN_RUNC_URL="${RELEASE_GARDEN_RUNC_URL:-https://bosh.io/d/github.com/cloudfoundry/garden-runc-release}"
RELEASE_CFLINUXFS2_ROOTFS_URL="${RELEASE_CFLINUXFS2_ROOTFS_URL:-https://bosh.io/d/github.com/cloudfoundry/cflinuxfs2-release}"
RELEASE_CF_RABBITMQ_URL="${RELEASE_CF_RABBITMQ_URL:-https://bosh.io/d/github.com/pivotal-cf/cf-rabbitmq-release}"
#RELEASE_CF_RABBITMQ_BROKER_URL="${RELEASE_CF_RABBITMQ_URL:-https://bosh.io/d/github.com/pivotal-cf/cf-rabbitmq-broker}"

BOSH_UPLOADS='BOSH_STEMCELL RELEASE_CF RELEASE_DIEGO RELEASE_GARDEN_RUNC RELEASE_CFLINUXFS2_ROOTFS RELEASE_CF_RABBITMQ'

INFO 'Uploading Bosh release(s)'
for i in $BOSH_UPLOADS; do
	eval base_url="\$${i}_URL"
	eval version="\$${i}_VERSION"

	[ -n "$version" ] && url="$base_url?v=$version" || url="$base_url"

	# Determine upload type
	echo "$i" | grep -Eq '^RELEASE' && UPLOAD_TYPE=release || UPLOAD_TYPE=stemcell

	INFO "Starting upload of $i"
	"$BOSH" upload-$UPLOAD_TYPE --fix "$url"

	unset base_url version
done

# Ensure we end with a newline, sometimes uploading doesn't end with a newline
echo
