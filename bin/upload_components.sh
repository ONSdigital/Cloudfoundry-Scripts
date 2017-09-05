#!/bin/sh
#
# See https://bosh.io/releases/github.com/cloudfoundry/cf-release and check 'Compatible Releases and Stemcells' for versions
#

set -e

BASE_DIR="`dirname \"$0\"`"

DEPLOYMENT_NAME="$1"

. "$BASE_DIR/common.sh"

record_version(){
	local item_name="$1"
	local var_name="$2"

	[ -z "$var_name" ] && FATAL 'Missing parameters'

	awk -v item_name="$item_name" -v var_name="$var_name" '{if($1 == item_name){ gsub("\*$","",$2); printf("%s_VERSION=\"%s\"\n",var_name,$2)}}'
}

# https://bosh.io/releases/github.com/cloudfoundry/cf-release
CF_VERSION="${2:-$CF_VERSION}"
# https://bosh.io/releases/github.com/cloudfoundry/diego-release
DIEGO_VERSION="${3:-$DIEGO_VERSION}"
# https://bosh.io/releases/github.com/cloudfoundry/garden-runc-release
GARDEN_RUNC_VERSION="${4:-$GARDEN_RUNC_VERSION}"
# https://bosh.io/releases/github.com/cloudfoundry/cflinuxfs2-release
CFLINUXFS2_VERSION="${5:-$CFLINUXFS2_VERSION}"
# https://bosh.io/releases/github.com/pivotal-cf/cf-rabbitmq-release
CF_RABBITMQ_VERSION="${6:-$CF_RABBITMQ_VERSION}"

# Stemcell
# https://bosh.io/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent
BOSH_STEMCELL_URL="${BOSH_STEMCELL_URL:-https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent}"

# Releases
CF_URL="${CF_URL:-https://bosh.io/d/github.com/cloudfoundry/cf-release}"
DIEGO_URL="${DIEGO_URL:-https://bosh.io/d/github.com/cloudfoundry/diego-release}"
GARDEN_RUNC_URL="${GARDEN_RUNC_URL:-https://bosh.io/d/github.com/cloudfoundry/garden-runc-release}"
CFLINUXFS2_URL="${CFLINUXFS2_URL:-https://bosh.io/d/github.com/cloudfoundry/cflinuxfs2-release}"
CF_RABBITMQ_URL="${CF_RABBITMQ_URL:-https://bosh.io/d/github.com/pivotal-cf/cf-rabbitmq-release}"
#CF_RABBITMQ_BROKER_URL="${CF_RABBITMQ_URL:-https://bosh.io/d/github.com/pivotal-cf/cf-rabbitmq-broker}"

BOSH_RELEASES='CF DIEGO GARDEN_RUNC CFLINUXFS2 CF_RABBITMQ'
BOSH_STEMCELLS='BOSH_STEMCELL'

BOSH_UPLOADS="$BOSH_STEMCELLS $BOSH_RELEASES"

[ -f "$RELEASE_CONFIG_FILE" ] && rm "$RELEASE_CONFIG_FILE"
[ -f "$RELEASE_CONFIG_FILE" ] && rm "$STEMCELL_CONFIG_FILE"

INFO 'Uploading Bosh release(s)'
for i in $BOSH_UPLOADS; do
	eval base_url="\$${i}_URL"
	eval version="\$${i}_VERSION"
	COMPONENT="`basename $i | sed $SED_EXTENDED -e 's/-release//g'`"

	[ -n "$version" ] && url="$base_url?v=$version" || url="$base_url"

	# Determine upload type
	if echo "$i" | grep -Eq 'STEMCELL'; then
		UPLOAD_TYPE=stemcell
		TYPES=stemcells
		OUTPUT_FILE="$STEMCELL_CONFIG_FILE"
	else
		UPLOAD_TYPE=release
		TYPES=releases
		OUTPUT_FILE="$RELEASE_CONFIG_FILE"
	fi

	INFO "Starting upload of $i"
	"$BOSH" upload-$UPLOAD_TYPE --fix "$url"

	"$BOSH" $TYPES | record_version "$COMPONENT" "$i" >>"$OUTPUT_FILE"

	unset base_url version
done

# Ensure we end with a newline, sometimes uploading doesn't end with a newline
echo

INFO 'Bosh Releases'
"$BOSH" releases

INFO 'Bosh Stemcells'
"$BOSH" stemcells
