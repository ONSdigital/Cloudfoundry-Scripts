#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

#
# See https://bosh.io/releases/github.com/cloudfoundry/cf-release and check 'Compatible Releases and Stemcells' for versions
#
# https://bosh.io/releases/github.com/cloudfoundry/cf-release
RELEASE_CF_VERSION="${1:-$RELEASE_CFLINUXFS2_ROOTFS_VERSION}"
# https://bosh.io/releases/github.com/cloudfoundry/diego-release
RELEASE_DIEGO_VERSION="${2:-$RELEASE_DIEGO_VERSION}"
# https://bosh.io/releases/github.com/cloudfoundry/garden-runc-release
RELEASE_GARDEN_RUNC_VERSION="${3:-$RELEASE_GARDEN_RUNC_VERSION}"
# https://bosh.io/releases/github.com/cloudfoundry/cflinuxfs2-release
RELEASE_CFLINUXFS2_ROOTFS_VERSION="${4:-$RELEASE_CFLINUXFS2_ROOTFS_VERSION}"
# https://bosh.io/releases/github.com/cloudfoundry-community/cf-services-contrib-release
RELEASE_CF_SERVICES_CONTRIB_VERSION="${5:-$RELEASE_CF_SERVICES_CONTRIB_VERSION}"

# https://bosh.io/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent
STEMCELL_BOSH_AWS_XEN_HVM_UBUNTU_TRUSTY_VERSION="${5:-$STEMCELL_BOSH_AWS_XEN_HVM_UBUNTU_TRUSTY_VERSION}"

# Releases
RELEASE_CF_URL='https://bosh.io/d/github.com/cloudfoundry/cf-release'
RELEASE_DIEGO_URL='https://bosh.io/d/github.com/cloudfoundry/diego-release'
RELEASE_GARDEN_RUNC_URL='https://bosh.io/d/github.com/cloudfoundry/garden-runc-release'
RELEASE_CFLINUXFS2_ROOTFS_URL='https://bosh.io/d/github.com/cloudfoundry/cflinuxfs2-release'
RELEASE_CF_SERVICES_CONTRIB_URL='https://bosh.io/d/github.com/cloudfoundry-community/cf-services-contrib-release'

# Stemcells
STEMCELL_BOSH_AWS_XEN_HVM_UBUNTU_TRUSTY_URL='https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent'

BOSH_UPLOADS='STEMCELL_BOSH_AWS_XEN_HVM_UBUNTU_TRUSTY RELEASE_CF RELEASE_DIEGO RELEASE_GARDEN_RUNC RELEASE_CFLINUXFS2_ROOTFS RELEASE_CF_SERVICES_CONTRIB_URL'

INFO 'Uploading Bosh release(s)'
for i in $BOSH_UPLOADS; do
	eval base_url="\$${i}_URL"
	eval version="\$${i}_VERSION"

	[ -n "$version" ] && url="$base_url?v=$version" || url="$base_url"

	# Determine upload type
	echo "$i" | grep -Eq '^RELEASE' && UPLOAD_TYPE=release || UPLOAD_TYPE=stemcell

	INFO "Starting parallel upload of $i"
	"$BOSH" upload-$UPLOAD_TYPE --fix "$url" &
	PIDS="$PIDS $!"

	unset base_url version
done

# Wait for completion
wait $PIDS
