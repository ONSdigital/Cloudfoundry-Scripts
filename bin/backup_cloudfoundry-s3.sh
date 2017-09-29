#!/bin/sh
#
# Backup/restore all of a deployments S3 buckets to/from the shared backup S3 bucket
#

set -e

BASE_DIR="`dirname \"$0\"`"

export NON_AWS_DEPLOY=true

s3_location(){
	echo $1 | grep -Eq '^s3://'
}

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
ACTION="${2:-backup}"
SRC_OR_DST="${3:-s3_backups}"

for i in 1 2 3; do
	[ -n "$1" ] && shift 1
done

. "$BASE_DIR/common-aws.sh"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist '$DEPLOYMENT_DIR'"

load_outputs "$STACK_OUTPUTS_DIR"

[ -n "$aws_region" ] && export AWS_DEFAULT_REGION="$aws_region"

# s3_bucket_resource_names contains a list of variable names that are then
# expanded to give the real bucket name. We do this so we so we can logically
# backup/restore them to/from the shared S3 bucket
# eg
# dropletbucket -> dropletbucket-21490hdj -> backups up to shared_bucket/deployment_name/dropletbucket
OLDIFS="$IFS"
IFS=","
for _bucket in $s3_bucket_resource_names; do
	var_name="`echo $_bucket | lowercase_aws`"

	eval s3_bucket="\$$var_name"

	for _ignore in $S3_BUCKET_IGNORES; do
		if [ x"$_ignore" = x"$_bucket" ]; then
			skip=1

			continue
		fi
	done

	if [ -n "$skip" ]; then
		unset skip

		continue
	fi

	if ! [ -n "$s3_bucket" -a x"$s3_bucket" != x"\$" ]; then
		WARN "Unable to find bucket name for $_bucket"

		error=1

		continue
	fi

	# The shared bucket name is either the source or the destination
	if [ x"$ACTION" = x"backup" ]; then
		log_name='Backup'
		src="s3://$s3_bucket"
		dst="$SRC_OR_DST/$_bucket"

		if ! s3_location "$dst" && [ ! -d "$dst" ]; then
			mkdir -p "$dst"
		fi

	elif [ x"$ACTION" = x"restore" ]; then
		log_name='Restore'
		src="$SRC_OR_DST/$_bucket"
		dst="s3://$s3_bucket"

		if ! s3_location "$src" && [ ! -d "$src" ]; then
			WARN "Restore directory does not exist: $src"

			STATE='FAILED'
			LOG_LEVEL='FATAL'

			continue
		fi
	else

		FATAL "Unknown action: $ACTION"
	fi

	"$AWS" s3 sync --acl bucket-owner-full-control --delete "$src" "$dst"
done
IFS="$OLDIFS"

"${LOG_LEVEL:-INFO}" "$log_name ${STATE:-Successful}"
