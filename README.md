# AWS/Bosh/Cloudfoundry Scripts

Various scripts to handle the life cycle of AWS Cloudformation, Bosh and Cloudfoundry.  Most of the parameters are
position dependant. Most of the time, if a parameter is not critical it can be set to NONE and it will be ignored -
but please check in the script if this is supported.


- backup\_cloudfoundry-databases.sh
  - Run errands from https://github.com/ONSdigital/postgresql-databases-release.  This only backs up PostgreSQL
    databases.  Any database can be backed up, as long as the instance running the errand can reach the database
    - Parameters: `Deployment_Name`

- backup\_cloudfoundry-s3.sh
  - Backup various internal Bosh/Cloudfoundry buckets to another S3 bucket.  This uses subdirectories that are named
    after
    the S3 source bucket
    -  Parameters: `Deployment_Name [backup|restore] [s3://destinaion|dir_destination]`

- bosh-cmd.sh
  - Helper script that pulls in the correct configuration to run the Bosh CLI. Any parameters after the *Deployment
    Name* are passed directly to the Bosh CLI
    - Parameters: `Deployment_Name [Parameter-1 ... Parameter-N]`

- bosh-env.sh
  - Called by the various setup\_cf-\* scripts to set some required variables

- bosh-ssh.sh
  - Helper script to call the Bosh CLI with the correct options to allow SSH'ing onto a given host
    - Parameters: `Deployment_Name Destination SSH_Host [Gateway_User] [Gateway_Host]`

- bosh\_generate\_release.sh
  - Script to generate a release for upload onto Bosh
    - Parameters: `Deployment_Name Release_Directory [Blob_1 ... Blob_N]`

- ca-tool.sh
  - Generic script that creates CA and key pairs signed by the CA
    - Parameters: `--ca-name|-C CA_Name [--new-ca|-N] [--update-ca] [--name|-n Name] [--update-name] [--key-size|-k]
                      [--not-basic-critical|-b] [--not-extended-critical|-c]
                      [--organisation|-o Organisation_Part1 ... Organisation_PartN]
                      [--generate-public-key|-p] [--generate-public-key-ssh-fingerprint|-f]
                      [--subject-alt-names|-s Subject_Alt_Name_Part1 ...Subject_Alt_Name_PartN] [--not-trusted|-t]`

- cf\_delete.sh
  - Simple script to login to Cloudfoundry and delete the named app
    - Parameters: `Deployment_Name CF_App`

- cf\_push.sh
  - Simple script to login to Cloudfoundry and push the named app
    - Parameters: `Deployment_Name CF_App [CF_Space] [CF_Organisation]`

- common-aws.sh
  - Common parts for the various AWS scripts

- common-bosh.sh
  - Common parts for the various Bosh scripts

- common.sh
  - Common parts for the various scripts

- create\_aws\_cloudformation.sh
  - Creates an AWS infrastructure using various Cloudformation Templates
    - Parameters: `Deployment_Name [AWS_Config_Prefix] [Hosted_Zone] [AWS_Region] [AWS_Access_Key_ID] [AWS_Secret_Access_Key]`
    - Environmental variables: `HOSTED_ZONE, AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEBUG=true|false, AWS_PROFILE, CLOUDFORMATION_DIR, IGNORE_MISSING_CONFIG=true|false
                                SKIP_STACK_OUTPUTS_DIR, SKIP_EXISTING=true|false, REGENERATE_SSH_KEY=true|false, DELETE_AWS_SSH_KEY=true|false`

- create\_dbs.sh
  - Reads the named Bosh manifest and creates the named databases
    - Parameters: `Deployment_Name [Bosh_Full_Manifest_Name] [Bosh_Cloud_Config_Manifest_Name] [Bosh_Lite_Manifest_Name] [Bosh_Preamble_Manifest_Name] [Bosh_Static_IPs_Manifest_Name]
                   [Manifests_Dir] [Internal_Domain]`
- create\_postgresql\_db.sh
  - Create the named database and user
- delete\_aws\_cloudformation.sh
  - Delete a group of AWS Cloudformation
- delete\_cloudfoundry.sh
  - Delete a Bosh deployment and delete the Bosh initial environment
- deploy\_cloudfoundry.sh
  - Deploys Cloudfoundry - this actually deploys any Bosh manifests, but has so far been soley used to deploy various
    parts of Cloudfoundry
- display\_cf\_vms.sh
  - Wraps `bosh vms` to provide a continually updated list of instances
- emergency\_delete\_aws\_stack.sh
  - Very simple/stupid script that deletes any AWS Cloudformation stacks that match a given prefix
- export-roles-orgs-user.sh
  - Simple script that exports users, organisations, spaces and roles from a given Cloudfoundry
- find\_external\_ip.sh
  - Simple script to find a hosts external IP
- functions.sh
  - General functions used by the various scripts
- generate-ssl.sh
  - Wrapper script around ca-tool.sh that creates the various CAs & keypairs required by Cloudfoundry.  Everything is
    outputted into a YML file that can be sucked in by Bosh
- install\_deps.sh
  - Script to install various dependencies (eg awscli, cf-uaac)
- install\_packages-EL.sh
  - Script to install various packages on Redhat/CentOS that then allow install\_deps.sh to run
- process\_cidrs.sh
  - Script to generate various network related config, eg CIDR sizes, static/reserved IP ranges
- setup\_cf-admin.sh
  - Create a basic Cloudfoundry admin user
- setup\_cf-elasticache-broker.sh
  - Upload the Cloudfoundry ElastiCache broker
- setup\_cf-orgspace.sh
  - Create a Cloudfoundry organisation and space
- setup\_cf-rds-broker.sh
  - Upload the Cloudfoundry RDS broker
- setup\_cf-service-broker.sh
  - Generic script to setup a Cloudfoundry service broker
- setup\_cf.sh
  - Script that calls the variopus setup\_cf-\* scripts to configure a deployed Cloudfoundry instance
- template.sh
  - Base template
- update\_aws\_cloudformation.sh
  - Update an existing set of AWS Cloudformation templates
- upload\_components.sh
  - Upload various Cloudfoundry releases and stemcells.  Also records the uploaded versions
- vendor\_update.sh
  - Interactive script to make the handling vendor'd Git repositories a little simplier
