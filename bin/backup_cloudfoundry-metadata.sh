#!/bin/sh
#
# Backup/restore metadata (CF users, spaces, orgs, services, etc) from a given S3 bucket. Use cf-mgnt to generate/import the metadata
#
# WIP... untested
#
# Variables:
#	DEPLOYMENT_NAME=[Deployment Name]
# Parameters:
#	[Deployment Name]
#	[backup|restore]
#
# Requires:
#	common-aws.sh

set -e

BASE_DIR="`dirname \"$0\"`"

export NON_AWS_DEPLOY=true

DEPLOYMENT_NAME="${1:-$DEPLOYMENT_NAME}"
ACTION="${2:-backup}"


UPDATE_ACTIONS='update-org-quotas update-org-users update-spaces update-spaces-quotas update-spaces-users update-space-security-groups'
DELETE_ACTIONS='delete-orgs delete-spaces'
CREATE_ACTIONS='create-orgs create-org-private-domains create-spaces'
BACKUP_ACTIONS='export-config'

. "$BASE_DIR/common-aws.sh"

[ -f "$CF_CREDENTIALS" ] || FATAL "$CF_CREDENTIALS does not exist"

. "$CF_CREDENTIALS"

if which cf-mgnt >/dev/null 2>&1; then
	CF_MGNT='cf-mgnt'

elif [ -f "$BIN_DIR/cf-mgnt" ]; then
	CF_MGNT="$BIN_DIR/cf-mgnt"

	installed_bin cf-mgnt
elif [ -z "$CF_MGNT" ]; then
	FATAL Unable to find cf-mgnt tool
fi

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist '$DEPLOYMENT_DIR'"

[ -f "$DEPLOYMENT_DIR/cf-credentials-admin.sh" ] || FATAL "CF admin credentials file does not exist: $DEPLOYMENT_DIR/cf-credentials-admin.sh"

INFO 'Loading AWS outputs'
load_outputs "$STACK_OUTPUTS_DIR"

. "$DEPLOYMENT_DIR/cf-credentials-admin.sh"

# The shared bucket name is either the source or the destination
if [ x"$ACTION" = x"backup" ]; then
	log_name='Backup'

	[ -d "$DEPLOYMENT_DIR/metadata" ] && rm -rf "$DEPLOYMENT_DIR/metadata"

	mkdir -p "$DEPLOYMENT_DIR/metadata"

	ACTIONS="$BACKUP_ACTIONS"


elif [ x"$ACTION" = x"restore" ]; then
	log_name='Restore'

	# Not sure we if the delete-{orgs,spaces} deletes non-existing orgs, or the orgs its about to create
	ACTIONS="$DELETE_ACTIONS $CREATE_ACTIONS $UPDATE_ACTIONS"
else

	FATAL "Unknown action: $ACTION"
fi

for a in $ACTIONS; do
	if ! "$CF_MGNT" "$a" --user-id "$CF_ADMIN_USERNAME" --client-secret "$CF_ADMIN_CLIENT_SECRET" \
		--config-dir "$DEPLOYMENT_DIR/metadata" \
		--system-domain "system.$domain_name"; then

		WARN "$log_name step $a failed"

		failed=1
	fi
done

[ -n "$failed" ] && FATAL "$log_name failed"

INFO "$log_name successful"
