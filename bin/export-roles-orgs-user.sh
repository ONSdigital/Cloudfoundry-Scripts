#!/bin/sh
#
# Export:
#	services			'cf service-brokers'
#	service provided services
#

export CF_COLOR=false

for i in 01_create-org.sh 02_create-space.sh 03_create-users.sh 04_space-roles.sh 05_org-roles.sh; do
	[ -f "$i" ] && rm -f "$i"
done

for org in `cf orgs 2>/dev/null | awk '!/^(name|Getting .*|No .*FAILED|OK)?$/'`; do
	echo "Inspecting Organisation: $org"

	echo "cf create-org \"$org\"" >>01_create-org.sh

	cf target -o "$org" 2>&1 >/dev/null

	echo '. finding spaces'
	cf spaces | awk -v org="$org" '!/^(name|Getting .*|No .*|FAILED)?$/{
		gsub(" *","")
		printf("cf create-space \"%s\" -o \"%s\"\n",$1,org)
	}' >>02_create-space.sh

	echo '. finding users'
	# This seems to generate repeating passwords: first 4-ish will be the same, second 5-ish will be the same,
	# third 8-ish will be the same & last 32 (+?) will be the same
	cf org-users -a "$org" | awk '!/^(USERS|Getting .*|FAILED|No .*|\s*(cf_)?admin)?$/{
		gsub(" *","")
		print $1
	}' >>users

	for space in `cf spaces 2>&1 | awk '!/^(name|Getting .*|No .*|FAILED)?$/'`; do
		echo ". inspecting space: $space"

		echo '.. inspecting space roles'
		cf space-users "$org" "$space" | awk -v org="$org" -v space="$space" '!/^(name|Getting .*|No .*|\s*(cf_)?admin)?$/{
			gsub("^ *","")
			if($0 ~ /SPACE MANAGER/){
				role="SpaceManager"
			}else if($0 ~ /SPACE DEVELOPER/){
				role="SpaceDeveloper"
			}else if($0 ~ /SPACE AUDITOR/){
				role="SpaceAuditor"
			}else{
				printf("cf set-space-role \"%s\" \"%s\" \"%s\" \"%s\"\n",$1,org,space,role)
			}
		}' >>04_space-roles.sh

		echo '.. inspect space services'
		cf target -o "$org" -s "$space"

		for service in `cf services | awk '!/^(name.*|Getting .*|OK|No .*|\s*(cf_)?admin)?$/{ print $1 }'`; do
			cf service "$service" | awk -F': *' '{
				if(/Service instance/){
					instance=$2
				}else if(/Service/){
					service=$2
				}else if(/Bound apps/){
					apps=$2
					printf("Service: %s, Instance: %s, Bound Apps: %s\n",service,instance,apps)
				}
			}'
		done | sort -k4 >>999_service-apps.txt
			
	done

	echo '. finding organisation roles'
	cf org-users "$org" 2>&1 | awk -v org="$org" '!/^(USERS|Getting .*|No .*|FAILED|\s*(cf_)?admin)?$/{
		gsub("^ *","")
		if($0 ~ /ORG MANAGER/){
			role="OrgManager"
		}else if($0 ~ /BILLING MANAGER/){
			role="BillingManager"
		}else if($0 ~ /ORG AUDITOR/){
			role="OrgAuditor"
		}else{
			printf("cf set-org-role \"%s\" \"%s\" \"%s\"\n",$1,org,role)
		}
	}' >>05_org-roles.sh
done

awk '{
	a[$1]++
}END{
	cmd="openssl rand -base64 16 | sed \"s/==//g\""
	for(i in a){
		cmd | getline password
		close(cmd)
		printf("cf create-user \"%s\" \"%s\"\n",i,password)
	}
}' users | sort -k 3 >03_create-users.sh

rm -f users

cf service-brokers | awk '!/^(name.*|Getting .*|OK|No .*|\s*(cf_)?admin)?$/{ print $1 }' | sort >998_service-brokers.txt

ls 01_create-org.sh 02_create-space.sh 03_create-users.sh 04_space-roles.sh 05_org-roles.sh

