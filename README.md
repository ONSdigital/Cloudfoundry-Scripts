# AWS/Bosh/Cloudfoundry Scripts

Various scripts to handle the life cycle of AWS Cloudformation, Bosh and Cloudfoundry.  Most of the parameters are
position dependant. Most of the time, if a parameter is not critical it can be set to NONE and it will be ignored -
but please check in the script if this is supported.

Generally, the way to get a full deployment of Cloudfoundry is to run the following:
- `create_aws_cloudformation.sh`
- `deploy_cloudfoundry.sh`

Currently, the deploying Cloudfoundry (using `deploy_cloudfoundry.sh`) fails first time due to some problems with
package compilation.  If the script is re-run with `REUPLOAD_COMPONENTS=true` then the deployment generally
completes.


## Scripts

- backup\_cloudfoundry-branch.sh
  - Backs up the current deployment branch to an S3 bucket.
    - Parameters: `DEPLOYMENT_NAME ACTION=backup|restore SRC_OR_DST=s3://destinaion|dir_destination`
    - Environmental Variables: `DEPLOYMENT_NAME ACTION SRC_OR_DST`
    - Defaults: `ACTION='backup' SRC_OR_DST='s3_backets'`

- backup\_cloudfoundry-databases.sh
  - Run backup errands.
    - Parameters: `DEPLOYMENT_NAME`
    - Environmental Variables: `DEPLOYMENT_NAME`

- backup\_cloudfoundry-metadata.sh
  - Calls cf-mgnt to backup/restore Cloudfoundry org, space, user & role metadata.  The data is stored under the deployment
    directory under another directory called `metadata`
    - Parameters: `DEPLOYMENT_NAME ACTION=backup|restore`
    - Environmental Variables: `DEPLOYMENT_NAME ACTION`
    - Defaults: `ACTION='backup'`

- backup\_cloudfoundry-s3.sh
  - Backup various internal Bosh/Cloudfoundry buckets to another S3 bucket.  This uses subdirectories that are named
    after the S3 source bucket
    - Parameters: `DEPLOYMENT_NAME ACTION=backup|restore SRC_OR_DST=s3://destinaion|dir_destination`
    - Environmental Variables: `DEPLOYMENT_NAME ACTION SRC_OR_DST`
    - Defaults: `ACTION='backup' SRC_OR_DST='s3_backets'`

- bosh-cmd.sh
  - Helper script that pulls in the correct configuration to run the Bosh CLI. Any parameters after the *DEPLOYMENT_NAME*
    are passed directly to the Bosh CLI
    - Parameters: `DEPLOYMENT_NAME [Parameter1 ... ParameterN]`
    - Environmental Variables: `DEPLOYMENT_NAME`

- bosh-env.sh
  - Called by the various setup\_cf-\* scripts to set some required variables

- bosh-ssh.sh
  - Helper script to call the Bosh CLI with the correct options to allow SSH'ing onto a given host
    - Parameters: `DEPLOYMENT_NAME SSH_HOST [GATEWAY_USER] [GATEWAY_HOST]`
    - Defaults: `GATEWAY_USER='vcap' GATEWAY_HOST='$director_dns'`

- bosh\_generate\_release.sh
  - Script to generate a release for upload onto Bosh
    - Parameters: `DEPLOYMENT_NAME RELEASE_DIR [Blob_1 ... Blob_N]`
    - Environmental Variables: `DEPLOYMENT_NAME RELEASE_DIR RELEASE_BLOB_DESTINATION`
    - Defaults: `RELEASE_BLOB_DESTINATION='blobs'`

- ca-tool.sh
  - Generic script that creates CA and key pairs signed by the CA
    - Parameters: `--ca-name|-C CA_NAME [--new-ca|-N] [--update-ca] [--name|-n NAME] [--update-name] [--key-size|-k KEY_SIZE]
                      [--not-basic-critical|-b] [--not-extended-critical|-c]
                      [--organisation|-o Organisation_Part1 ... Organisation_PartN]
                      [--generate-public-key|-p] [--generate-public-key-ssh-fingerprint|-f]
                      [--subject-alt-names|-s Subject_Alt_Name_Part1 ...Subject_Alt_Name_PartN] [--not-trusted|-t]`
    - Environmental Variables: `KEY_SIZE HASH_TYPE ORGANISTAION VALID_DAYS CA_NAME NEW_CA=[1] NAME UPDATE_NAME=[1]'
                                GENERATE_PUBLIC_KEY=[1] GENERATE_PUBLIC_KEY_SSH_FINGER_PRINT=[1] TRUST_OPT BASIC_USAGE
                                EXTENDED_USAGE`
    - Defaults: `KEY_SIZE='4096' HASH_TYPE='sha512' ORGANISTAION='Organisation' VALID_DAYS='3650' TRUST_OPT='--trustout'
                 BASIC_USAGE='critical,' EXTENDED_USAGE='critical,'`

- cf\_delete.sh
  - Simple script to login to Cloudfoundry and delete the named app
    - Parameters: `DEPLOYMENT_NAME CF_APP`
    - Environmental Variables: `DEPLOYMENT_NAME CF_APP`

- cf\_push.sh
  - Simple script to login to Cloudfoundry and push the named app
    - Parameters: `DEPLOYMENT_NAME CF_APP [CF_SPACE] [CF_ORGANISATION]`
    - Environmental Variables: `DEPLOYMENT_NAME CF_APP CF_SPACE CF_ORGANISATION`
    - Defaults: `CF_APP='Test' CF_ORGANISATION="$organisation"`

- common-aws.sh
  - Common parts for the various AWS scripts

- common-bosh.sh
  - Common parts for the various Bosh scripts

- common.sh
  - Common parts for the various scripts

- create\_aws\_cloudformation.sh
  - Creates an AWS infrastructure using various Cloudformation Templates
    - Parameters: `DEPLOYMENT_NAME [AWS_CONFIG_PREFIX] [HOSTED_ZONE] [AWS_REGION] [AWS_ACCESS_KEY_ID] [AWS_SECRET_ACCESS_KEY]`
    - Environmental variables: `DEPLOYMENT_NAME AWS_CONFIG_PREFIX HOSTED_ZONE AWS_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
                                AWS_DEBUG=true|false AWS_PROFILE CLOUDFORMATION_DIR IGNORE_MISSING_CONFIG=true|false
                                SKIP_STACK_OUTPUTS_DIR=true|false SKIP_EXISTING=true|false REGENERATE_SSH_KEY=true|false
                                DELETE_AWS_SSH_KEY=true|false`
    - Defaults: `AWS_CONFIG_PREFIX='AWS-Bosh' AWS_REGION='eu-central-1' AWS_DEBUG=false AWS_PROFILE='default'
                 CLOUDFORMATION_DIR='Cloudformation' IGNORE_MISSING=true SKIP_EXISTING=true REGENERATE_SSH_KEY=false
                 DELETE_AWS_SSH_KEY=false AWS_DEBUG=false`

- create\_dbs.sh
  - Reads the named Bosh manifest and creates the named databases
    - Environmental Variables: `BOSH_FULL_MANIFEST_FILE`

- create\_postgresql\_db.sh
  - Create the named database and user
    - Parameters: `--admin-username ADMIN_USERNAME --new-database-name NEW_DATABASE_NAME
                   [--admin-database ADMIN_DATABASE] [--admin-password ADMIN_PASSWORD]
                   [--postgres-hostname POSTGRESQL_HOSTNAME] [--postgresql-hostname POSTGRESQL_HOSTNAME]
                   [--postgres-port POSTGRESQL_PORT] [--postgresql-port POSTGRESQL_PORT]
                   [--new-database-username NEW_DATABASE_USERNAME] [--new-database-password NEW_DATABASE_PASSWORD]
                   [--jump-userhost JUMP_USERHOST] [--ssh-key SSH_KEY] [--extensions EXTENSIONS]`
    - Environmental Variables: `ADMIN_DATABASE_NAME ADMIN_USERNAME ADMIN_PASSWORD POSTGRESQL_HOSTNAME POSTGRESQL_PORT
                                NEW_DATABASE_NAME NEW_DATABASE_USERNAME NEW_DATABASE_PASSWORD JUMP_USERHOST SSH_KEY
                                EXTENSIONS`
    - Defaults: `ADMIN_DATABASE_NAME='postgres' ADMIN_USERNAME='postgres'`

- delete\_aws\_cloudformation.sh
  - Delete a group of AWS Cloudformation stacks
    - Parameters: `DEPLOYMENT_NAME [AWS_CONFIG_PREFIX] [HOSTED_ZONE] [AWS_REGION] [AWS_ACCESS_KEY_ID] [AWS_SECRET_ACCESS_KEY]`
    - Environmental Variables: `AWS_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEBUG=true|false AWS_PROFILE
                                CLOUDFORMATION_DIR BOSH_SSH_CONFIG KEEP_SSH_KEY`
    - Defaults: `AWS_REGION='eu-central-1' AWS_DEBUG=false KEEP_SSH_KEY=false AWS_CONFIG_PREFIX='AWS-Bosh' AWS_PROFILE='default'`

- delete\_cloudfoundry.sh
  - Delete a Bosh deployment and delete the Bosh initial environment
    - Parameters: `DEPLOYMENT_NAME [BOSH_FULL_MANIFEST_PREFIX] [BOSH_CLOUD_MANIFEST_PREFIX] [BOSH_LITE_MANIFEST_NAME]
                  [BOSH_PREAMBLE_MANIFEST_NAME] [BOSH_STATIC_IPS_PREFIX] [INTERNAL_DOMAIN]`
    - Environmental Variables: `BOSH_LITE_OPS_FILE_NAME BOSH_FULL_OPS_FILE_NAME INTERACTIVE NO_FORCE_TTY`
    - Defaults: `INTERACTIVE=false NO_FORCE_TTY=false BOSH_FULL_MANIFEST_PREFIX='Bosh-Template'
                 BOSH_CLOUD_MANIFEST_PREFIX='$BOSH_FULL_MANIFEST_PREFIX-AWS-CloudConfig' BOSH_LITE_MANIFEST_NAME='Bosh-Template'
                 BOSH_PREAMBLE_MANIFEST_NAME='Bosh-Template-preamble' BOSH_STATIC_IPS_PREFIX='Bosh-static-ips'
                 MANIFESTS_DIR='Bosh-Manifests' INTERNAL_DOMAIN='cf.internal'`

- deploy\_cloudfoundry.sh
  - Deploys Cloudfoundry - this actually deploys any Bosh manifests, but has so far been soley used to deploy various
    parts of Cloudfoundry
    - Parameters: `DEPLOYMENT_NAME [BOSH_FULL_MANIFEST_PREFIX] [BOSH_CLOUD_MANIFEST_PREFIX] [BOSH_LITE_MANIFEST_NAME]
                  [BOSH_PREAMBLE_MANIFEST_NAME] [BOSH_STATIC_IPS_PREFIX] [INTERNAL_DOMAIN]`
    - Environmental Variables: `BOSH_LITE_OPS_FILE_NAME BOSH_FULL_OPS_FILE_NAME INTERACTIVE NO_FORCE_TTY DELETE_BOSH_ENV
                                DELETE_BOSH_STATE REGENERATE_PASSWORDS REGENERATE_NETWORKS_CONFIG REGENERATE_SSL
                                DELETE_SSL_CA REGENERATE_BOSH_CONFIG REINTERPOLATE_LITE_STATIC_IPS REINTERPOLATE_FULL_STATIC_IPS
                                REUPLOAD_COMPONENTS NORUN_PREDEPLOY NORUN_BOSH_PREAMBLE SKIP_POST_DEPLOY_ERRANDS`
    - Defaults: `INTERACTIVE=false NO_FORCE_TTY=false BOSH_FULL_MANIFEST_PREFIX='Bosh-Template'
                BOSH_CLOUD_MANIFEST_PREFIX='$BOSH_FULL_MANIFEST_PREFIX-AWS-CloudConfig' BOSH_LITE_MANIFEST_NAME='Bosh-Template'
                BOSH_PREAMBLE_MANIFEST_NAME='Bosh-Template-preamble' BOSH_STATIC_IPS_PREFIX='Bosh-static-ips'
                MANIFESTS_DIR='Bosh-Manifests' INTERNAL_DOMAIN='cf.internal' DELETE_BOSH_ENV=false REGENERATE_PASSWORDS=false
                REGENERATE_NETWORKS_CONFIG=false REGENERATE_BOSH_CONFIG=false REINTERPOLATE_LITE_STATIC_IPS=false
                DELETE_BOSH_ENV=false REGENERATE_BOSH_ENV=false REINTERPOLATE_FULL_STATIC_IPS=false REUPLOAD_COMPONENTS=false
                NORUN_PREDEPLOY=false NORUN_BOSH_PREAMBLE=false SKIP_POST_DEPLOY_ERRANDS=false`

- display\_cf\_vms.sh
  - Wraps `bosh vms` to provide a continually updated list of instances
    - Parameters: `DEPLOYMENT_NAME [--failing|failing|f|--vitals|vitals|v] [INTERVAL] [OUTPUT_TYPE]`
    - Environmental Variables: `DEPLOYMENT_NAME OPTION INTERVAL OUTPUT_TYPE BOSH_OPTS`
    - Defaults: `OPTION='vitals' INTERVAL=5 OUTPUT_TYPE='tty'`

- emergency\_delete\_aws\_stack.sh
  - Very simple/stupid script that deletes any AWS Cloudformation stacks that match a given prefix
    - Parameters: `STACK_PREFIX`
    - Environmental Variables: `AWS_PROFILE`
    - Defaults: `AWS_PROFILE='default'`

- export-roles-orgs-user.sh
  - Simple script that generates various scripts to create users, organisations, spaces and roles when pointed at a given Cloudfoundry.
    Additionally the script will generate a few text files that contain data about services & service brokers.

- find\_external\_ip.sh
  - Simple script to find a hosts external IP

- functions.sh
  - General functions used by the various scripts
    - Functions: `FATAL() DEBUG() WARN() INFO() _date() calculate_dns() ip_to_decimal() decimal_to_ip() stack_file_name()
                aws_region() aws_credentials() find_aws() validate_json_files() parse_aws_cloudformation_outputs()
                find_aws_parameters() generate_parameters_file() capitalise_aws() lowercase_aws() update_parameters_file()
                stack_exists() check_cloudformation_stack() calculate_dns_ip() show_duplicate_output_names() bosh_int()
                bosh_env() bosh_deploy() cf_app_url() installed_bin() findpath() prefix_vars() generate_password()
                load_outputs() load_output_vars()`

- generate-ssl.sh
  - Wrapper script around ca-tool.sh that creates the various CAs & keypairs required by Cloudfoundry.  Everything is
    outputted into a YML file that can be sucked in by Bosh
    - Parameters: `[EXTERNAL_CA_NAME] [INTERNAL_CA_NAME] [OUTPUT_YML] [ORGANISATION] [APPS_DOMAIN] [SYSTEM_DOMAIN] [SERVICE_DOMAIN]
                   [EXTERNAL_DOMAIN] [ONLY_MISSING]`
    - Environmental Variables: `EXTERNAL_CA_NAME INTERNAL_CA_NAME OUTPUT_YML ORGANISATION ONLY_MISSING`
    - Defaults: `ONLY_MISSING=true`

- install\_deps.sh
  - Script to install various dependencies (eg awscli, cf-uaac)
    - Parameters: `[INSTALL_AWS]`
    - Environmental Variables: `BOSH_CLI_VERSION BOSH_GITHUB_RELEASE_URL BOSH_CLI_RELEASE_TYPE CF_CLI_VERSION CF_GITHUB_RELEASE_URL
                                CF_CLI_RELEASE_TYPE NO_AWS PIP_VERSION_SUFFIX`
    - Defaults: `INSTALL_AWS=true`

- install\_packages-EL.sh
  - Script to install various packages on Redhat/CentOS that then allow install\_deps.sh to run

- process\_cidrs.sh
  - Script to generate various network related config, eg CIDR sizes, static/reserved IP ranges
    - Parameters: `NETWORK_NAME CIDR`
    - Environmental Variables: `DEFAULT_DEFAULT_ROUTE_OFFEST DEFAULT_RESERVED_START_OFFSET DEFAULT_RESERVED_SIZE
                                ${NETWORK_NAME}_DEFAULT_ROUTE_OFFSET ${NETWORK_NAME}_RESERVED_START_OFSET
                                ${NETWORK_NAME}_RESERVED_SIZE ${NETWORK_NAME}_STATIC_START_OFFSET
                                ${NETWORK_NAME}_STATIC_SIZE`
    - Defaults: `DEFAULT_DEFAULT_ROUTE_OFFEST=1 DEFAULT_RESERVED_START_OFFSET=1 DEFAULT_RESERVED_SIZE=10`

- setup\_cf.sh
  - Script that calls the variopus setup\_cf-\* scripts to configure a deployed Cloudfoundry instance
    - Parameters: `DEPLOYMENT_NAME [EMAIL_ADDRESS] [ORG_NAME] [TEST_SPACE] [DONT_SKIP_SSL_VALIDATION]`
    - Environmental Variables: `SKIP_TESTS`
    - Defaults: `EMAIL_ADDRESS='NONE' ORG_NAME="$organisation" TEST_SPACE='Test'`

- setup\_cf-admin.sh
  - Create a basic Cloudfoundry admin user
    - Parameters: `DEPLOYMENT_NAME USERNAME EMAIL PASSWORD DONT_SKIP_SSL_VALIDATION`
    - Defaults: `EMAIL_ADDRESS=NONE ORG_NAME="$organisation" TEST_SPACE='Test' DONT_SKIP_SSL_VALIDATION=false`

- setup\_cf-elasticache-broker.sh
  - Upload the Cloudfoundry ElastiCache brokerA
    - Parameters: `DEPLOYMENT_NAME BROKER_NAME`
    - Defaults: `BROKER_NAME='elasticache'`

- setup\_cf-orgspace.sh
  - Create a Cloudfoundry organisation and space
    - Parameters: `DEPLOYMENT_NAME [ORG_NAME] [SPACE_NAME]`
    - Defaults: `ORG_NAME="$organisation" SPACE_NAME='Test'`

- setup\_cf-rds-broker.sh
  - Upload the Cloudfoundry RDS broker
    - Parameters: `DEPLOYMENT_NAME RDS_BROKER_DB_NAME RDS_BROKER_NAME CF_ORG`
    - Environmental Variables: `DEPLOYMENT_NAME RDS_BROKER_DB_NAME RDS_BROKER_NAME DEFAULT_RDS_BROKER_DB_NAME DEFAULT_RDS_BROKER_NAME IGNORE_EXISTING
                                SERVICES_SPACE`
    - Defaults: `RDS_BROKER_DB_NAME='rds_broker' RDS_BROKER_NAME='rds_broker' SERVICES_SPACE='Services'`

- setup\_cf-service-broker.sh
  - Generic script to setup a Cloudfoundry service broker
    - Parameters: `DEPLOYMENT_NAME [SERVICE_NAME] [SERVICE_USERNAME] [SERVICE_PASSWORD] [SERVICE_URL]`
    - Environmental Variables: `DEPLOYMENT_NAME SERVICE_NAME SERVICE_USERNAME SERVICE_PASSWORD SERVICE_URL DONT_SKIP_SSL_VALIDATION IGNORE_EXISTING`

- template.sh
  - Base template

- update\_aws\_cloudformation.sh
  - Update an existing set of AWS Cloudformation templates
    - Parameters: `DEPLOYMENT_NAME [AWS_CONFIG_PREFIX] [HOSTED_ZONE] [AWS_REGION] [AWS_ACCESS_KEY_ID] [AWS_SECRET_ACCESS_KEY]`
    - Environmental Variables: `HOSTED_ZONE AWS_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEBUG=true|false AWS_PROFILE
                                CLOUDFORMATION_DIR IGNORE_MISSING_CONFIG=true|false SKIP_STACK_OUTPUTS_DIR SKIP_MISSING
                                SKIP_STACK_PREAMBLE_OUTPUTS_CHECK SKIP_STACK_PREAMBLE_OUTPUTS_CHECK`
    - Defaults: `AWS_CONFIG_PREFIX='AWS-Bosh' AWS_REGION='eu-central-1' AWS_DEBUG=false AWS_PROFILE='default'
                 CLOUDFORMATION_DIR='Cloudformation' SKIP_MISSING='false' SKIP_STACK_PREAMBLE_OUTPUTS_CHECK='false'`

- upload\_components.sh
  - Upload various Cloudfoundry releases and stemcells.  Also records the uploaded versions
    - Parameters: `DEPLOYMENT_NAME CF_VERSION DIEGO_VERSION GARDEN_RUNC_VERSION CFLINUXFS2_VERSION CF_RABBITMQ_VERSION CF_SMOKE_TEST_VERSION`
    - Environmental Variables: `CF_VERSION DIEGO_VERSION GARDEN_RUNC_VERSION CFLINUXFS2_VERSION CF_RABBITMQ_VERSION CF_SMOKE_TEST_VERSION
                                CF_URL DIEGO_URL GARDEN_RUNC_URL CFLINUXFS2_URL CF_RABBITMQ_URL CF_SMOKE_TEST_URL`

- vendor\_update.sh
  - Interactive script to make the handling vendor'd Git repositories a little simplier
    Parameters: `[Vendored_Repo1..Vendored_RepoN]`
