# AWS/Bosh/Cloudfoundry Scripts

Various scripts to handle the life cycle of AWS Cloudformation, Bosh and Cloudfoundry.  Most of the parameters are
position dependant. Most of the time, if a parameter is not critical it can be set to NONE and it will be ignored -
but please check in the script if this is supported.

Generally, the way to get a full deployment of Cloudfoundry is to run the following:
- `create_aws_cloudformation.sh`
- `deploy_cloudfoundry.sh`

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

- `functions.sh`
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

- `setup_cf.sh`
  - Script that calls the variopus setup\_cf-\* scripts to configure a deployed Cloudfoundry instance

- `setup_cf-admin.sh`
  - Create a basic Cloudfoundry admin user

- `setup_cf-elasticache-broker.sh`
  - Upload the Cloudfoundry ElastiCache brokerA

- `setup_cf-orgspace.sh`
  - Create a Cloudfoundry organisation and space

- `setup_cf-rds-broker.sh`
  - Upload the Cloudfoundry RDS broker

- `setup_cf-service-broker.sh`
  - Generic script to setup a Cloudfoundry service broker

### Misc scripts

- `find_external_ip.sh`
  - Simple script to find a hosts external IP

### Pre-install scripts

- `install_deps.sh`
  - Script to install various dependencies (eg awscli, cf-uaac)

- `install_packages-EL.sh`
  - Script to install various packages on Redhat/CentOS that then allow install\_deps.sh to run

- `process_cidrs.sh`
  - Script to generate various network related config, eg CIDR sizes, static/reserved IP ranges

### Repository related scripts

- `vendor_update.sh`
  - Interactive script to make the handling vendor'd Git repositories a little simplier

- `protected_branch.sh`
  - Checks if the current branch contains a file `protection_state` containing 'protected' or not
