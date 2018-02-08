# AWS/Bosh/Cloudfoundry Scripts

Various scripts to handle the life cycle of AWS Cloudformation, Bosh and Cloudfoundry.  Most of the parameters are
position dependant. Most of the time, if a parameter is not critical it can be set to NONE and it will be ignored -
but please check in the script if this is supported.

Generally, the way to get a full deployment of Cloudfoundry is to run the following:
- `create_aws_cloudformation.sh`
- `deploy_cloudfoundry.sh`

# CURRENTLY BEING UPDATED - script details without extra details and in `backticks` have been updated

## Template(s)

- `template.sh`
  - Base template

## Sourced scripts

These are non-user facing scripts and are pulled in by the 'Scripts'

- `bosh-env.sh`
  - Called by the various setup\_cf-\* scripts to set some required variables

- `common.sh`
  - Common parts for the various scripts

- `common-aws.sh`
  - Common parts for the various AWS scripts

- `common-bosh.sh`
  - Common parts for the various Bosh scripts

- `common-bosh-login.sh`
  - Common parts to login to Bosh

- functions.sh
  - General functions used by the various scripts

## Scripts

### AWS related scripts

- `create_aws_cloudformation.sh`
  - Creates an AWS infrastructure using various Cloudformation Templates

- `delete_aws_cloudformation.sh`
  - Delete a group of AWS Cloudformation stacks

- `simple-delete_aws_stack.sh`
  - Very simple/stupid script that deletes any AWS Cloudformation stacks that match a given prefix

- `update_aws_cloudformation.sh`
  - Update an existing set of AWS Cloudformation templates

### Bosh CLI helper scripts

These scripts setup the environment for the Bosh CLI to save having to setup the environment

- `bosh-cmd.sh`
  - Helper script that pulls in the correct configuration to run the Bosh CLI. Any parameters after the *DEPLOYMENT_NAME*
    are passed directly to the Bosh CLI

- `bosh-create_release.sh`
  - Script to create a release for upload onto Bosh

- `bosh-display_vms.sh`
  - Wraps `bosh vms` to provide a continually updated list of instances

- `bosh-ssh.sh`
  - Helper script to call the Bosh CLI with the correct options to allow SSH'ing onto a given host

### Cloudfoundry backup/restore scripts

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

### Cloudfoundry CLI helper scripts

- `cf_delete.sh`
  - Simple script to login to Cloudfoundry and delete the named app

- `cf-export-roles-orgs-user.sh`
  - Simple script that generates scripts to re-create users, organisations, spaces and roles when pointed at a given Cloudfoundry.
    Additionally the script will generate a few text files that contain data about services & service brokers.

- `cf_push.sh`
  - Simple script to login to Cloudfoundry and push the named app

### Cloudfoundry deployment scripts

- `delete_cloudfoundry.sh`
  - Delete a Bosh deployment and delete the Bosh initial environment

- `deploy_cloudfoundry.sh`
  - Deploys Cloudfoundry - this actually deploys any Bosh manifests, but has so far been soley used to deploy various
    parts of Cloudfoundry

### Cloudfoundry setup scripts

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


### Misc scripts

- find\_external\_ip.sh
  - Simple script to find a hosts external IP

### Pre-install scripts

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

### Repository related scripts

- vendor\_update.sh
  - Interactive script to make the handling vendor'd Git repositories a little simplier
    Parameters: `[Vendored_Repo1..Vendored_RepoN]`

- protected\_branch.sh
