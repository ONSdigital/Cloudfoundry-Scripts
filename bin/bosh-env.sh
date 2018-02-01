#

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
shift

[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment directory does not exist: $DEPLOYMENT_DIR"
[ -f "$BOSH_DIRECTOR_CONFIG" ] || FATAL "No deployment confiugration available: $BOSH_DIRECTOR_CONFIG"

INFO 'Loading AWS outputs'
load_outputs "$STACK_OUTPUTS_DIR"
