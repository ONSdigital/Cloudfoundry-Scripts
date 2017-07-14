#!/bin/echo Should be sourced

DEPLOYMENT_NAME="$1"

DEPLOYMENT_DIR="$DEPLOYMENT_BASE_DIR/$DEPLOYMENT_NAME"
STACK_OUTPUTS_DIR="$DEPLOYMENT_BASE_DIR/$DEPLOYMENT_NAME/outputs"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
shift

[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment directory does not exist: $DEPLOYMENT_DIR"
[ -f "$DEPLOYMENT_DIR/bosh-config.sh" ] || FATAL "No deployment confiugration available: $DEPLOYMENT_DIR/bosh-config.sh"

load_outputs "$DEPLOYMENT_NAME" "$STACK_OUTPUTS_DIR"
