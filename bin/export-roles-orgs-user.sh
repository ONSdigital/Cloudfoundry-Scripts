#!/bin/sh

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
	cf org-users -a "$org" | awk '!/^(USERS|Getting)?$/{
		gsub(" *","")
		"head /dev/urandom | tr -dc \"[:alnum:]\" | head -c 16" | getline password
		printf("cf create-user \"%s\" \"%s\"\n",$1,password)
	}' >>03_create-users.sh


	for space in `cf spaces 2>&1 | awk '!/^(name|Getting .*|No .*|FAILED)?$/'`; do
		echo ". inspecting space: $space"

		echo '.. inspecting space rolls'
		cf space-users "$org" "$space" | awk -v org="$org" -v space="$space" '!/^(name|Getting .*|No .*)?$/{
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
	done

	echo '. finding organisation roles'
	cf org-users "$org" 2>&1 | awk -v org="$org" '!/^(USERS|Getting|No.*found)?$/{
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

ls 01_create-org.sh 02_create-space.sh 03_create-users.sh 04_space-roles.sh 05_org-roles.sh 06_services.sh
