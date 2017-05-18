#

cf_app_url(){
	local application="$1"

	[ -z "$application" ] && FATAL 'No application provided'


	# We blindly assume we are logged in and pointing at the right place
	# Sometimes we seem to get urls, sometimes routes?
	"$CF" app "$application" | awk -F" *: *" '/^(urls|routes):/{print $2}'
}

SERVICES_SPACE="Services"

installed_bin cf
