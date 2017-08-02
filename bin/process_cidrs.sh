#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

DEFAULT_DEFAULT_ROUTE_OFFEST="${DEFAULT_DEFAULT_ROUTE_OFFEST:-1}"
DEFAULT_RESERVED_START_OFFSET="${DEFAULT_RESERVED_START_OFFSET:-1}"
DEFAULT_RESERVED_SIZE="${DEFAULT_RESERVED_SIZE:-10}"

ip_to_decimal(){
        echo $1 | awk -F. '{sum=$4+($3*256)+($2*256^2)+($1*256^3)}END{printf("%d\n",sum)}'
}

decimal_to_ip(){
	[ -n "$2" ] && value="`expr $1 + $2`" || value="$1"

        # Urgh
        echo $value |  awk '{address=$1; for(i=1; i<=4; i++){d[i]=address%256; address-=d[i]; address=address/256;} for(j=1; j<=4; j++){ printf("%d",d[5-j]);if( j==4 ){ printf("\n") }else{ printf(".")}}}'
}

NETWORK=$1
# Optional
ENV_PREFIX="$2"

[ -z "$NETWORK" ] && FATAL 'Not enough parameters'
[ -z "$ENV_PREFIX" ] && WARN 'Env prefix not provided'

network_uc="`echo "$NETWORK" | tr '[[:lower:]]' '[[:upper:]]'`"

# This is from one of the outputs-*.sh, after it has been, potentially, pre-processed by load_outputs()
eval cidr="\$${ENV_PREFIX}${NETWORK}_cidr"

# These are from the environment (eg Jenkins parameters)
eval default_route_offset="\$${network_uc}_DEFAULT_ROUTE_OFFSET"
eval reserved_start_offset="\$${network_uc}_RESERVED_START_OFSET"
eval reserved_size="\$${network_uc}_RESERVED_SIZE"
eval static_start_offset="\$${network_uc}_STATIC_START_OFFSET"
eval static_size="\$${network_uc}_STATIC_SIZE"

[ -z "$cidr" ] && FATAL "Nothing found for ${NETWORK}_cidr"

decimal="`ip_to_decimal "$cidr"`"

echo "${ENV_PREFIX}${NETWORK}_default_route='`decimal_to_ip "$decimal" "${default_route_offset:-$DEFAULT_DEFAULT_ROUTE_OFFEST}"`'"
echo "${ENV_PREFIX}${NETWORK}_reserved_start='`decimal_to_ip "$decimal" "${reserved_start_offset:-$DEFAULT_RESERVED_START_OFFSET}"`'"
echo "${ENV_PREFIX}${NETWORK}_reserved_stop='`decimal_to_ip "$decimal" "${reserved_size:-$DEFAULT_RESERVED_SIZE}"`'"

if [ -n "$static_start_offset" -a -n "$static_size" ]; then
	eval static_stop_offset="`expr $static_start_offset + $static_size - 1`"

	echo "${ENV_PREFIX}${NETWORK}_static_start='`decimal_to_ip "$decimal" "$static_start_offset"`'"
	echo "${ENV_PREFIX}${NETWORK}_static_stop='`decimal_to_ip "$decimal" "$static_stop_offset"`'"

	for i in `seq $static_start_offset $static_stop_offset`; do
		eval static_offset="`expr $static_start_offset + ${count:-0}`"

		count="`expr ${count:-0} + 1`"

		echo "${ENV_PREFIX}${NETWORK}_static_ip$count='`decimal_to_ip "$decimal" "$static_offset"`'"

	done
fi
