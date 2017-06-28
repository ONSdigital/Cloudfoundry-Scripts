#!/bin/sh

for i in 01_create-org.sh 02_create-space.sh 03_create-users.sh 04_space-roles.sh 05_org-roles.sh; do
	[ -f "$i" ] && rm -f "$i"
done

for org in `cf orgs 2>/dev/null | awk '!/^(name|Getting|$)/'`; do
	echo "cf create-org \"$org\"" >>01_create-org.sh

	cf target -o "$org" 2>&1 >/dev/null

	cf spaces  | awk -v org="$org" '!/^(name|Getting|No.*found|$)/{
		gsub(" *","")
		printf("cf create-space \"%s\" -o \"%s\"\n",$1,org)
	}' >>02_create-space.sh
	
	cf org-users -a "$org" | awk '!/^(USERS|Getting|$)/{
		gsub(" *","")
		"head /dev/urandom | tr -dc \"[:alnum:]\" | head -c 16" | getline password
		printf("cf create-user \"%s\" \"%s\"\n",$1,password)
	}' >>03_create-users.sh


	for space in `cf spaces | awk '!/^(name|Getting|No.*found|$)/'`; do
		cf space-users "$org" "$space" | awk -v org="$org" -v space="$space" '!/^(name|Getting|No.*found|$)/{
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

	cf org-users "$org" | awk -v org="$org" '!/^(USERS|Getting|No.*found|$)/{
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

ls 01_create-org.sh 02_create-space.sh 03_create-users.sh 04_space-roles.sh 05_org-roles.sh
