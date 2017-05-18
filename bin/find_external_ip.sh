#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

if [ -n "$VCAP_APPLICATION" ]; then
	HOST="`echo \"$VCAP_APPLICATION\" | sed -re 's/^.*"cf_api":"([^"]+)".*$/\1/g' -e 's,^https?://api.system.([^"]),nat.\1,g'`"

	echo "$HOST" | grep -qE '^[a-z0-9.-]+$' || FATAL 'Unable to determine NAT hostname'

	if which dig >/dev/null 2>&1; then
		IP="`dig +short \"$HOST\"`"
	elif which host >/dev/null 2>&1; then
		IP="`host \"$HOST\" | awk '/ [0-9.]+$/{print $NF; exit}'`"
	else
		FATAL "Unable to perform a lookup on: '$HOST'"
	fi

	[ -z "$IP" ] && FATAL "Unable to determin external IP from \$VCAP_APPLICATION: $VCAP_APPLICATION"

	echo "$IP"

elif which curl >/dev/null 2>&1; then
	curl -sq 'http://bot.whatismyipaddress.com'

else
	FATAL 'Unable to determine external IP'
fi
