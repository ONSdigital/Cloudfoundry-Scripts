# AWS/Bosh/Cloudfoundry Scripts

Various scripts to handle the life cycle of AWS Cloudformation, Bosh and Cloudfoundry.  Most of the parameters are
position dependant. Most of the time, if a parameter is not critical it can be set to NONE and it will be ignored -
but please check in the script if this is supported.

Generally, the way to get a full deployment of Cloudfoundry is to run the following:
- `create_aws_cloudformation.sh`
- `deploy_cloudfoundry.sh`


# CURRENTLY BEING UPDATED - script details without extra details and in `backslashes` have been updated

## Template(s)

- template.sh
  - Base template

## Sourced scripts

These are non-user facing scripts and are pulled in by the 'Scripts'

- `bosh-env.sh`
  - Called by the various setup\_cf-\* scripts to set some required variables

- `common.sh`
  - Common parts for the various scripts

- `common-aws.sh`
  - Common parts for the various AWS scripts

- common-bosh.sh
  - Common parts for the various Bosh scripts

- functions.sh
  - General functions used by the various scripts

## Scripts

### Scripts to backup Cloudfoundry bits

- `backup_cloudfoundry-branch.sh`
  - Backs up the current deployment branch to an S3 bucket.

- `backup_cloudfoundry-databases.sh`
  - Run backup errands.

- `backup_cloudfoundry-metadata.sh`
  - Calls cf-mgnt to backup/restore Cloudfoundry org, space, user & role metadata.  The data is stored under the deployment
    directory under another directory called `metadata`

- `backup_cloudfoundry-s3.sh`
  - Backup various internal Bosh/Cloudfoundry buckets to another S3 bucket.  This uses subdirectories that are named
    after the S3 source bucket

### Helper scripts to perform Bosh CLI actions

These scripts setup the environment for the Bosh CLI to save having to setup the environment

- `bosh-cmd.sh`
  - Helper script that pulls in the correct configuration to run the Bosh CLI. Any parameters after the *DEPLOYMENT_NAME*
    are passed directly to the Bosh CLI

- `bosh-ssh.sh`
  - Helper script to call the Bosh CLI with the correct options to allow SSH'ing onto a given host

- `bosh-create_release.sh`
  - Script to create a release for upload onto Bosh
    - Parameters: `DEPLOYMENT_NAME RELEASE_DIR [Blob_1 ... Blob_N]`
    - Environmental Variables: `DEPLOYMENT_NAME RELEASE_DIR RELEASE_BLOB_DESTINATION`
    - Defaults: `RELEASE_BLOB_DESTINATION='blobs'`

###

- `ca-tool.sh` - *NO LONGER USED*
  - Generic script that creates CA and key pairs signed by the CA

### Cloudfoundry CLI related scripts

- `cf_delete.sh`
  - Simple script to login to Cloudfoundry and delete the named app

- `cf_push.sh`
  - Simple script to login to Cloudfoundry and push the named app

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
