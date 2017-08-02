#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

DEFAULT_ROUTE_OFFEST='1'
RESERVED_START_OFFSET='1'
RESERVED_SIZE='10'

ip_to_decimal(){
        echo $1 | awk -F. '{sum=$4+($3*256)+($2*256^2)+($1*256^3)}END{printf("%d\n",sum)}'
}

decimal_to_ip(){
	[ -n "$2" ] && value="`expr $1 + $2`" || value="$1"

        # Urgh
        echo $value |  awk '{address=$1; for(i=1; i<=4; i++){d[i]=address%256; address-=d[i]; address=address/256;} for(j=1; j<=4; j++){ printf("%d",d[5-j]);if( j==4 ){ printf("\n") }else{ printf(".")}}}'
}

for network in $@; do
	eval cidr="\$${network}_cidr"
	eval default_route_offset="\$${network}_default_route_offset"
	eval reserved_start_offset="\$${network}_reserved_start_ofset"
	eval reserved_size="\$${network}_reserved_size"
	eval static_start_offset="\$${network}_static_start_offset"
	eval static_size="\$${network}_static_size"

	[ -z "$cidr" ] && FATAL "Nothing found for ${network}_cidr"

	decimal="`ip_to_decimal "$cidr"`"

	echo "${network}_default_route=""`decimal_to_ip "$decimal" "${default_route_offset:-$DEFAULT_ROUTE_OFFEST}"`"
	echo "${network}_reserved_start=""`decimal_to_ip "$decimal" "${reserved_start_offset:-$RESERVED_START_OFFSET}"`"
	echo "${network}_reserved_stop=""`decimal_to_ip "$decimal" "${reserved_size:-$RESERVED_SIZE}"`"

	if [ -n "$static_start_offset" -a -n "$static_size" ]; then
		echo "${network}_static_start=""`decimal_to_ip "$decimal" "$static_start_offset"`"
		echo "${network}_static_stop=""`decimal_to_ip "$decimal" "$dec_static_stop"`"
	fi
done

