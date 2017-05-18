#!/bin/sh
#

set -ex

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

# Set secure umask - the default permissions for ~/.bosh/config are wide open
INFO 'Setting secure umask'
umask 077

SKIP_SSL_GENERATION='true'
SKIP_PASSWORD_GENERATION='true'
SKIP_COMPONENT_UPLOAD='true'
SKIP_STATE_CHECK='true'
SKIP_BOSH_CONFIG_CREATION='true'

BOSH_DELETE_ENV='true'

export SKIP_SSL_GENERATION SKIP_PASSWORD_GENERATION SKIP_COMPONENT_UPLOAD SKIP_STATE_CHECK SKIP_BOSH_CONFIG_CREATION BOSH_DELETE_ENV

#"$BOSH" delete-deployment $BOSH_INTERACTIVE_OPT $BOSH_TTY_OPT

# We have to give Bosh quite a few details to delete itself, so we call deploy_cloudfoundry.sh with a few tweaks
# When we have Bosh/director deployed properly, we'll need to refactor things. We'll have to create a Bosh instance and use that to delete the setup
# It may be possible that create-env will let us create a full fat CF setup
"$BASE_DIR/deploy_cloudfroundry.sh" $@
