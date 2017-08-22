#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

export NON_AWS_DEPLOY=true

. "$BASE_DIR/common-aws.sh"

s3_location(){
	echo $1 | grep -Eq '^s3://'
}

DEPLOYMENT_NAME="$1"
ACTION="${2:-backup}"
SRC_OR_DST="${3:-s3_backups}"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist '$DEPLOYMENT_DIR'"

shift

load_outputs "$STACK_OUTPUTS_DIR"

OLDIFS="$IFS"
IFS=","
for _s3 in `echo $s3_bucket_resource_names | lowercase_aws`; do
	eval s3_bucket="\$$_s3"

	if ! [ -n "$s3_bucket" -a x"$s3_bucket" != x"\$" ]; then
		WARN "Unable to find bucket name for $_s3"

		error=1

		continue
	fi

	if [ x"$action" = x"backup" ]; then
		src="s3://$s3_bucket"
		dst="$SRC_OR_DST/$_s3"

		if ! s3_location "$dst" && [ ! -d "$dst" ]; then
			mkdir -p "$dst"
		fi

	elif [ x"$action" = x"restore" ]; then
		src="$SRC_OR_DST/$_s3"
		dst="s3://$s3_bucket"

		if ! s3_location "$src" && [ ! -d "$src" ]; then
			WARN "Restore directory does not exist: $src"

			STATE='FAILED'
			LOG_LEVEL='FATAL'

			continue
		fi
	else
		FATAL "Unknown action: $action"
	fi

	"$AWS" --profile "$AWS_PROFILE" s3 sync --delete "$src" "$dst"
done
IFS="$OLDIFS"

"$LOG_LEVEL" "Backup $STATE"
