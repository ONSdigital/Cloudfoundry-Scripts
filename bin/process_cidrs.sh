#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

DEFAULT_DEFAULT_ROUTE_OFFEST="${DEFAULT_DEFAULT_ROUTE_OFFEST:-1}"
DEFAULT_RESERVED_START_OFFSET="${DEFAULT_RESERVED_START_OFFSET:-1}"
DEFAULT_RESERVED_SIZE="${DEFAULT_RESERVED_SIZE:-10}"

ip_sequence(){
	local name="$1"
	local type="$2"
	local base_ip="$3"
	local start="$4"
	local stop="$5"

	local offset
	local count=0

	for i in `seq "$start" "$stop"`; do
		count="`expr $count + 1`"

		 echo "${name}_${type}_ip$count='`decimal_to_ip "$base_ip" "$i"`'"
	done
}

ip_to_decimal(){
        echo $1 | awk -F. '{sum=$4+($3*256)+($2*256^2)+($1*256^3)}END{printf("%d\n",sum)}'
}

decimal_to_ip(){
	[ -n "$2" ] && value="`expr $1 + $2`" || value="$1"

        # Urgh
        echo $value |  awk '{address=$1; for(i=1; i<=4; i++){d[i]=address%256; address-=d[i]; address=address/256;} for(j=1; j<=4; j++){ printf("%d",d[5-j]);if( j==4 ){ printf("\n") }else{ printf(".")}}}'
}

NETWORK_NAME="$1"
CIDR=$2

[ -z "$NETWORK_NAME" ] && FATAL 'No network name provided'
[ -z "$CIDR" ] && FATAL 'No CIDR provided'

IP_BASE="`echo "$CIDR" | awk -F/ '{print $1}'`"

NETWORK_UC="`echo "$NETWORK_NAME" | tr '[[:lower:]]' '[[:upper:]]'`"

# These are from the environment (eg Jenkins parameters)
eval default_route_offset="\$${NETWORK_UC}_DEFAULT_ROUTE_OFFSET"
eval reserved_start_offset="\$${NETWORK_UC}_RESERVED_START_OFSET"
eval reserved_size="\$${NETWORK_UC}_RESERVED_SIZE"
eval static_start_offset="\$${NETWORK_UC}_STATIC_START_OFFSET"
eval static_size="\$${NETWORK_UC}_STATIC_SIZE"

DECIMAL_IP="`ip_to_decimal "$CIDR"`"

default_route_offset="${default_route_offset:-$DEFAULT_DEFAULT_ROUTE_OFFEST}"
reserved_start_offset="${reserved_start_offset:-$DEFAULT_RESERVED_START_OFFSET}"
reserved_size="${reserved_size:-$DEFAULT_RESERVED_SIZE}"
reserved_stop_offset="`expr "$reserved_start_offset" + "$reserved_size" - 1`"

echo "${NETWORK_NAME}_default_route='`decimal_to_ip "$DECIMAL_IP" "$default_route_offset"`'"
echo "${NETWORK_NAME}_reserved_start='`decimal_to_ip "$DECIMAL_IP" "$reserved_start_offset"`'"
echo "${NETWORK_NAME}_reserved_stop='`decimal_to_ip "$DECIMAL_IP" "$reserved_size"`'"

ip_sequence "$NETWORK_NAME" reserved "$DECIMAL_IP" "$reserved_start_offset" "$reserved_stop_offset"

if [ -n "$static_size" ]; then
	[ -z "$static_start_offset" ] && static_start_offset="`expr $reserved_stop_offset + 1`"

	static_stop_offset="`expr $static_start_offset + $static_size - 1`"

	[ x"$static_start_offset" = x"$reserved_stop_offset" ] && FATAL "Static start address is the same as the reserved end address: $static_start_offset & $reserved_stop_offset"

	echo "${NETWORK_NAME}_static_start='`decimal_to_ip "$DECIMAL_IP" "$static_start_offset"`'"
	echo "${NETWORK_NAME}_static_stop='`decimal_to_ip "$DECIMAL_IP" "$static_stop_offset"`'"

	ip_sequence "$NETWORK_NAME" static "$DECIMAL_IP" "$static_start_offset" "$static_stop_offset"
fi
