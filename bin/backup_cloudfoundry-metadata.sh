#!/bin/sh
#
# Backup/restore a deployment branch to/from the given S3 bucket
#
#
# WIP... untested
#

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

load_outputs_vars "$STACK_OUTPUTS_DIR" domain_name

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
	if ! "$CF_MGNT" "$a" --user-id "$CF_ADMIN_USERNAME" --client-secreet "$CF_ADMIN_CLIENT_SECRET" \
		--config-dir "$DEPLOYMENT_DIR/metadata" \
		--system-domain "system.$domain_name"; then

		WARN "$log_name step $a failed"

		failed=1
	fi
done

[ -n "$failed" ] && FATAL "$log_name failed"

INFO "$log_name successful"
