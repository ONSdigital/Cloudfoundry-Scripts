#!/bin/echo Should be sourced

DEPLOYMENT_NAME="$1"

DEPLOYMENT_FOLDER="$DEPLOYMENT_DIRECTORY/$DEPLOYMENT_NAME"
STACK_OUTPUTS_DIR="$DEPLOYMENT_DIRECTORY/$DEPLOYMENT_NAME/outputs"

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
shift

[ -d "$DEPLOYMENT_FOLDER" ] || FATAL "Deployment folder does not exist: $DEPLOYMENT_FOLDER"
[ -f "$DEPLOYMENT_FOLDER/bosh-config.sh" ] || FATAL "No deployment confiugration available: $DEPLOYMENT_FOLDER/bosh-config.sh"

load_outputs "$DEPLOYMENT_NAME" "$STACK_OUTPUTS_DIR"
