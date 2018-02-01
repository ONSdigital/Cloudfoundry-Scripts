#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

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

NETWORK_NAME="$1"
CIDR=$2

[ -z "$NETWORK_NAME" ] && FATAL 'No network name provided'
[ -z "$CIDR" ] && FATAL 'No CIDR provided'

DECIMAL_IP="`ip_to_decimal "$CIDR"`"
IP_BASE="`echo "$CIDR" | awk -F/ '{print $1}'`"
PREFIX_SIZE="`echo "$CIDR" | awk -F/ '{print $NF}'`"
NETWORK_UC="`echo "$NETWORK_NAME" | tr '[[:lower:]]' '[[:upper:]]'`"

# Provide some sensible defaults, these probably never need changing
DEFAULT_DEFAULT_ROUTE_OFFEST="${DEFAULT_DEFAULT_ROUTE_OFFEST:-1}"
DEFAULT_RESERVED_START_OFFSET="${DEFAULT_RESERVED_START_OFFSET:-1}"

# Provide a number of allocation sizes to avoid having to put in network sizes within the deployment scripts

# Provide sensible default reserved and static allocation sizes:
DEFAULT_RESERVED_SIZE="${DEFAULT_RESERVED_SIZE:-10}"
DEFAULT_STATIC_SIZE="${DEFAULT_STATIC_SIZE:-10}"

# Provide medium size reserved and static allocation sizes:
SMALL_RESERVED_SIZE="${LARGE_RESERVED_SIZE:-5}"
SMALL_STATIC_SIZE="${LARGE_STATIC_SIZE:-5}"

# Provide medium size reserved and static allocation sizes:
MEDIUM_RESERVED_SIZE="${LARGE_RESERVED_SIZE:-40}"
MEDIUM_STATIC_SIZE="${LARGE_STATIC_SIZE:-40}"

# Provide large size reserved and static allocation sizes:
LARGE_RESERVED_SIZE="${LARGE_RESERVED_SIZE:-75}"
LARGE_STATIC_SIZE="${LARGE_STATIC_SIZE:-75}"

# These are from the environment (eg Jenkins parameters)
eval default_route_offset="\$${NETWORK_UC}_DEFAULT_ROUTE_OFFSET"
eval reserved_start_offset="\$${NETWORK_UC}_RESERVED_START_OFSET"
#
eval reserved_size="\$${NETWORK_UC}_RESERVED_SIZE"
eval static_size="\$${NETWORK_UC}_STATIC_SIZE"

default_route_offset="${default_route_offset:-$DEFAULT_DEFAULT_ROUTE_OFFEST}"
reserved_start_offset="${reserved_start_offset:-$DEFAULT_RESERVED_START_OFFSET}"

# Automatically size network based on scale options
case "$PREFIX_SIZE" in
	[01][0-9]|2[0-3])
		eval RESERVED_STATIC_SCALE="\${${NETWORK_UC}_RESERVED_STATIC_SCALE:-LARGE}"
		eval STATIC_RESERVED_SCALE="\${${NETWORK_UC}_STATIC_RESERVED_SCALE:-LARGE}"
		;;
	24)
		eval RESERVED_STATIC_SCALE="\${${NETWORK_UC}_RESERVED_STATIC_SCALE:-MEDIUM}"
		eval STATIC_RESERVED_SCALE="\${${NETWORK_UC}_STATIC_RESERVED_SCALE:-MEDIUM}"
		;;
	2[5-7])
		eval RESERVED_STATIC_SCALE="\${${NETWORK_UC}_RESERVED_STATIC_SCALE:-DEFAULT}"
		eval STATIC_RESERVED_SCALE="\${${NETWORK_UC}_STATIC_RESERVED_SCALE:-DEFAULT}"
		;;
	28)
		eval RESERVED_STATIC_SCALE="\${${NETWORK_UC}_RESERVED_STATIC_SCALE:-SMALL}"
		eval STATIC_RESERVED_SCALE="\${${NETWORK_UC}_STATIC_RESERVED_SCALE:-SMALL}"
		;;
	*)
		FATAL "$NETWORK_UC Network size too small"
		;;
esac


[ -z "$reserved_size" ] && eval reserved_size="\$${RESERVED_STATIC_SCALE}_RESERVED_SIZE"
[ -z "$static_size" ] && eval static_size="\$${STATIC_RESERVED_SCALE}_STATIC_SIZE"

reserved_stop_offset="`expr "$reserved_start_offset" + "$reserved_size" - 1`"

echo "${NETWORK_NAME}_default_route='`decimal_to_ip "$DECIMAL_IP" "$default_route_offset"`'"
echo "${NETWORK_NAME}_reserved_start='`decimal_to_ip "$DECIMAL_IP" "$reserved_start_offset"`'"
echo "${NETWORK_NAME}_reserved_stop='`decimal_to_ip "$DECIMAL_IP" "$reserved_size"`'"

ip_sequence "$NETWORK_NAME" reserved "$DECIMAL_IP" "$reserved_start_offset" "$reserved_stop_offset"

static_start_offset="`expr $reserved_stop_offset + 1`"
static_stop_offset="`expr $reserved_stop_offset + $static_size`"

[ x"$static_start_offset" = x"$reserved_stop_offset" ] && FATAL "Static start address is the same as the reserved end address: $static_start_offset & $reserved_stop_offset"

echo "${NETWORK_NAME}_static_start='`decimal_to_ip "$DECIMAL_IP" "$static_start_offset"`'"
echo "${NETWORK_NAME}_static_stop='`decimal_to_ip "$DECIMAL_IP" "$static_stop_offset"`'"

ip_sequence "$NETWORK_NAME" static "$DECIMAL_IP" "$static_start_offset" "$static_stop_offset"
