#!/bin/sh
#
# Simple script that
#
# Parameters: none
# Variables: none
# Requires: nothing

set -e

export CF_COLOR=false

for i in 01_create-org.sh 02_create-space.sh 03_create-users.sh 04_space-roles.sh 05_org-roles.sh 06_quotas.sh 07_org_quotas.sh 08_space_quotas.sh \
	09_security_groups.sh \
	997_space_apps.txt 998_service-brokers.txt 999_service-apps.txt; do
	[ -f "$i" ] && rm -f "$i"
done

for org in `cf orgs 2>/dev/null | awk '!/^ *(name|Getting .*|No .*FAILED|OK)?$/'`; do
	echo "Inspecting Organisation: $org"

	org_quota="`cf org $org | awk '!/^ *quota:.*default$/ && !/^ *quota: *$/ && /^ *quota/{printf("-q %s",$2)}'`"

	echo '. inspecting organisation quota'
	echo "cf create-org $org_quota \"$org\"" | sed -re 's/  / /g' >>01_create-org.sh

	cf target -o "$org" 2>&1 >/dev/null


	echo '. finding users'
	# This seems to generate repeating passwords: first 4-ish will be the same, second 5-ish will be the same,
	# third 8-ish will be the same & last 32 (+?) will be the same
	cf org-users -a "$org" | awk '!/^ *(USERS|Getting .*|FAILED|No .*| *(cf_)?admin)?$/{
		gsub(" *","")
		print $1
	}' >>users

	echo '. finding spaces'
	for space in `cf spaces 2>&1 | awk '!/^(name|Getting .*|No .*|FAILED)?$/'`; do
		echo ". inspecting space: $space"
		echo '.. inspecting space quota'

		space_quota="`cf space $space | awk -F": +" '!/^ *(space quota:.*default|space quota: *|name|Getting .*|No .*|FAILED)?$/ && /^ *space quota:/{printf("-q %s",$2)}'`"
		space_asg="`cf space $space | awk -F": +" '!/^ *(name|Getting .*|No .*|FAILED|security group: *)?$/ && /^ *security groups:/{gsub(" *\\\(.*$",""); printf("--security-group-rules %s",$2)}'`"
		echo "cf create-space -o $org $space_quota $space_asg \"$space\"" | sed -re 's/  / /g' -e 's/, /,/g' >>02_create-space.sh

		echo '.. inspecting space roles'
		cf space-users "$org" "$space" | awk -v org="$org" -v space="$space" '!/^ *(name|Getting .*|No .*|(cf_)?admin)?$/{
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

		echo '.. inspecting space services'
		cf target -o "$org" -s "$space"

		echo '... inspecting space apps'
		cf apps | awk -v org="$org" -v space="$space" '!/^ *(name.*|Getting .*|OK|No .*|(cf_)?admin)?$/{ printf("Application: %s, Organisation: %s, Space: %s\n",$1,org,space) }' \
			>>997_space_apps.txt

		for service in `cf services | awk '!/^ *(name.*|Getting .*|OK|No .*|(cf_)?admin)?$/{ print $1 }'`; do
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
	cf org-users "$org" 2>&1 | awk -v org="$org" '!/^ *(USERS|Getting .*|No .*|FAILED|(cf_)?admin)?$/{
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

echo '. finding quotas'
cf quotas | awk '!/^ *(default|name.*|Getting .*|OK|No .*|$)/{
	total_memory = ($2 == "unlimited") ? -1 : $2
	instance_memory = ($3 == "unlimited") ? -1 : $3
	total_services = ($5 == "unlimited") ? -1 : $5
	allow_paid_plans = ($6 == "allowed") ? "--allow-paid-service-plans" : ""
	total_instances = ($7 == "unlimited") ? -1 : $7

	printf( "cf create-quota %s -m %s -i %s -s %s %s -a %s --reserved-route-ports %s\n", $1,total_memory,instance_memory,$4,total_services,allow_paid_plans,total_instances,$8)
}' | sed -re 's/  / /g' >06_quotas.sh

cf service-brokers | awk '!/^ *(name.*|Getting .*|OK|No .*|)?$/{ print $1 }' | sort >998_service-brokers.txt

[ -d asg ] || mkdir -p asg
echo '. finding security groups'
for i in `cf security-groups | awk '!/^ *(name .*|Name .*|Getting .*|OK|No .*)?$/{ gsub("^(#[0-9]+)? +","") gsub(" .*$","") g[$0]++ }END{ for(i in g) print i }'`; do
	echo ".. inspecting security group $i"
	cf security-group $i | awk '!/^ *(Rules|Name .*|Getting .*|OK|No .*)?$/{
		gsub("^\t","")
		print $0
	}' >"asg/$i.yml"

	echo "cf create-security-group $i asg/$i.yml" >>09_security_groups.sh
done

ls *

