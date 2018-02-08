#!/bin/sh
#
#
# Attempts to find an external IP
#
# Variables:
#	VCAP_APPLICATION
#
# Requires:
#	common.sh

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

if [ -n "$VCAP_APPLICATION" ]; then
	HOST="`echo \"$VCAP_APPLICATION\" | sed -re 's/^.*"cf_api":"([^"]+)".*$/\1/g' -e 's,^https?://api.system.([^"]),nat.\1,g'`"

	echo "$HOST" | grep -qE '^[a-z0-9.-]+$' || FATAL 'Unable to determine NAT hostname'

	if which dig >/dev/null 2>&1; then
		IPS="`dig +short \"$HOST\"`"
	elif which host >/dev/null 2>&1; then
		IPS="`host \"$HOST\" | awk '/ [0-9.]+$/{print $NF; exit}'`"
	else
		FATAL "Unable to perform a lookup on: '$HOST'"
	fi

	[ -z "$IPS" ] && FATAL "Unable to determin external IP from \$VCAP_APPLICATION: $VCAP_APPLICATION & $HOST"

	for ip in $IPS; do
		echo $ip
	done
else
	FATAL 'Unable to determine external IP(s)'
fi
