#

[ -z "$DEPLOYMENT_NAME" ] && FATAL 'Deployment name not provided'
[ -d "$DEPLOYMENT_DIR" ] || FATAL "Deployment does not exist '$DEPLOYMENT_DIR'"
[ -f "$BOSH_DIRECTOR_CONFIG" ] || FATAL "Bosh config does not exist: $BOSH_DIRECTOR_CONFIG"

eval export `prefix_vars "$BOSH_DIRECTOR_CONFIG"`

# Convert from relative to an absolute path
findpath BOSH_CA_CERT "$BOSH_CA_CERT"

export BOSH_CA_CERT

installed_bin bosh

INFO "Pointing Bosh at deployed Bosh: $BOSH_ENVIRONMENT"
"$BOSH" alias-env $BOSH_TTY_OPT -e "$BOSH_ENVIRONMENT" "$BOSH_ENVIRONMENT" >&2

INFO 'Attempting to login'
"$BOSH" log-in $BOSH_TTY_OPT >&2

