#!/bin/sh
#
# See https://bosh.io/releases/github.com/cloudfoundry/cf-release and check 'Compatible Releases and Stemcells' for versions
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

record_version(){
	local item_name="$1"
	local var_name="$2"

	[ -z "$var_name" ] && FATAL 'Missing parameters'

	awk -v item_name="$item_name" -v var_name="$var_name" 'if($1 == item_name){ gsub("\*$","",$2); printf("%s=\"%s\"\n",var_name,$2) }'
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
STEMCELL_URL="${STEMCELL_URL:-https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent}"

# Releases
CF_URL="${CF_URL:-https://bosh.io/d/github.com/cloudfoundry/cf-release}"
DIEGO_URL="${DIEGO_URL:-https://bosh.io/d/github.com/cloudfoundry/diego-release}"
GARDEN_RUNC_URL="${GARDEN_RUNC_URL:-https://bosh.io/d/github.com/cloudfoundry/garden-runc-release}"
CFLINUXFS2_URL="${CFLINUXFS2_URL:-https://bosh.io/d/github.com/cloudfoundry/cflinuxfs2-release}"
CF_RABBITMQ_URL="${CF_RABBITMQ_URL:-https://bosh.io/d/github.com/pivotal-cf/cf-rabbitmq-release}"
#CF_RABBITMQ_BROKER_URL="${CF_RABBITMQ_URL:-https://bosh.io/d/github.com/pivotal-cf/cf-rabbitmq-broker}"

BOSH_RELEASES='CF DIEGO GARDEN_RUNC CFLINUXFS2 CF_RABBITMQ'
BOSH_STEMCELLS='STEMCELL'

BOSH_UPLOADS="$BOSH_STEMCELLS $BOSH_RELEASES"

INFO 'Uploading Bosh release(s)'
for i in $BOSH_UPLOADS; do
	eval base_url="\$${i}_URL"
	eval version="\$${i}_VERSION"

	[ -n "$version" ] && url="$base_url?v=$version" || url="$base_url"

	# Determine upload type
	echo "$i" | grep -Eq 'STEMCELL' && UPLOAD_TYPE=stemcell || UPLOAD_TYPE=release

	INFO "Starting upload of $i"
	"$BOSH" upload-$UPLOAD_TYPE --fix "$url"

	unset base_url version
done

# Ensure we end with a newline, sometimes uploading doesn't end with a newline
echo

INFO 'Bosh Releases'
"$BOSH" releases

# Name                  Version   	Commit Hash  
# cf			272*		5b13d444+    
# cf-rabbitmq		226.0.0*	d6d9ba21+    
# cflinuxfs2		1.151.0*	4de03213+    
# diego			1.25.3*		dc59f5d      
# garden-runc		1.9.3*		55956f4      
# postgresql-databases	0+dev.2*	89d48db+     
# ~			0+dev.1		89d48db+     
for _b in $BOSH_RELEASES; do
	name="`echo $_b | tr '[[:upper:]]' '[[:lower:]]'`"

	"$BOSH" releases | record_version "$name" "$_b"
done >"$RELEASE_CONFIG_FILE"

INFO 'Bosh Stemcells'
"$BOSH" stemcells

# Name						Version	OS		CPI	CID                 
# bosh-aws-xen-hvm-ubuntu-trusty-go_agent	3445.7*	ubuntu-trusty	-	ami-fbaf1a94 light
for _b in $BOSH_RELEASES; do
	name="`echo $_b | tr '[[:upper:]]' '[[:lower:]]'`"
	url="\$${_b}_URL"
	stemcell="`basename "$url"`"

	"$BOSH" stemcells | record_version "$stemcell" "$_b"
done >"$STEMCELL_CONFIG_FILE"

