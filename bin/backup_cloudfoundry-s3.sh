#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

export NON_AWS_DEPLOY=true

s3_location(){
	echo $1 | grep -Eq '^s3://'
}

DEPLOYMENT_NAME="$1"
ACTION="${2:-backup}"
SRC_OR_DST="${3:-s3_backups}"

for i in 1 2 3; do
	[ -n "$1" ] && shift 1
done

. "$BASE_DIR/common-aws.sh"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist '$DEPLOYMENT_DIR'"

load_outputs "$STACK_OUTPUTS_DIR"

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

	if [ x"$ACTION" = x"backup" ]; then
		src="s3://$s3_bucket"
		dst="$SRC_OR_DST/$_bucket"

		if ! s3_location "$dst" && [ ! -d "$dst" ]; then
			mkdir -p "$dst"
		fi

	elif [ x"$ACTION" = x"restore" ]; then
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

	"$AWS" --profile "$AWS_PROFILE" s3 sync --acl bucket-owner-full-control --delete "$src" "$dst"
done
IFS="$OLDIFS"

"${LOG_LEVEL:-INFO}" "Backup ${STATE:-Successful}"
