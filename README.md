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
    - Parameters: `Deployment_Name [Bosh_Full_Manifest_Name]`

- create\_postgresql\_db.sh
  - Create the named database and user
    - Parameters: `--admin-username ADMIN_USERNAME --new-database-name NEW_DATABASE_NAME
                   [--admin-database ADMIN_DATABASE] [--admin-password ADMIN_PASSWORD]
                   [--postgres-hostname POSTGRESQL_HOSTNAME] [--postgresql-hostname POSTGRESQL_HOSTNAME]
                   [--postgres-port POSTGRESQL_PORT] [--postgresql-port POSTGRESQL_PORT]
                   [--new-database-username NEW_DATABASE_USERNAME] [--new-database-password NEW_DATABASE_PASSWORD]
                   [--jump-userhost JUMP_USERHOST] [--ssh-key SSH_KEY] [--extensions EXTENSIONS]`

- delete\_aws\_cloudformation.sh
  - Delete a group of AWS Cloudformation stacks
    - Parameters: `Deployment_Name [AWS_Config_Prefix] [Hosted_Zone] [AWS_Region] [AWS_Access_Key_ID] [AWS_Secret_Access_Key]`
    - Environmental Variables: `AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEBUG=true|false, AWS_PROFILE,
                                CLOUDFORMATION_DIR, BOSH_SSH_CONFIG, KEEP_SSH_KEY`

- delete\_cloudfoundry.sh
  - Delete a Bosh deployment and delete the Bosh initial environment
    - Parameters: `DEPLOYMENT_NAME [BOSH_FULL_MANIFEST_PREFIX] [BOSH_CLOUD_MANIFEST_PREFIX] [BOSH_LITE_MANIFEST_NAME]
                  [BOSH_PREAMBLE_MANIFEST_NAME] [BOSH_STATIC_IPS_PREFIX] [INTERNAL_DOMAIN]`
    - Environmental Variables: `BOSH_LITE_OPS_FILE_NAME BOSH_FULL_OPS_FILE_NAME INTERACTIVE NO_FORCE_TTY`


- deploy\_cloudfoundry.sh
  - Deploys Cloudfoundry - this actually deploys any Bosh manifests, but has so far been soley used to deploy various
    parts of Cloudfoundry
    - Parameters: `DEPLOYMENT_NAME [BOSH_FULL_MANIFEST_PREFIX] [BOSH_CLOUD_MANIFEST_PREFIX] [BOSH_LITE_MANIFEST_NAME]
                  [BOSH_PREAMBLE_MANIFEST_NAME] [BOSH_STATIC_IPS_PREFIX] [INTERNAL_DOMAIN]`
    - Environmental Variables: `BOSH_LITE_OPS_FILE_NAME BOSH_FULL_OPS_FILE_NAME INTERACTIVE NO_FORCE_TTY DELETE_BOSH_ENV
                                DELETE_BOSH_STATE REGENERATE_PASSWORDS REGENERATE_NETWORKS_CONFIG REGENERATE_SSL
                                DELETE_SSL_CA REGENERATE_BOSH_CONFIG REINTERPOLATE_LITE_STATIC_IPS REINTERPOLATE_FULL_STATIC_IPS
                                REUPLOAD_COMPONENTS NORUN_PREDEPLOY NORUN_BOSH_PREAMBLE SKIP_POST_DEPLOY_ERRANDS`

- display\_cf\_vms.sh
  - Wraps `bosh vms` to provide a continually updated list of instances
    - Parameters: `DEPLOYMENT_NAME [--failing|failing|f|--vitals|vitals|v] [INTERVAL] [OUTPUT_TYPE]`

- emergency\_delete\_aws\_stack.sh
  - Very simple/stupid script that deletes any AWS Cloudformation stacks that match a given prefix
    - Parameters: `STACK_PREFIX [AWS_PROFILE]`

- export-roles-orgs-user.sh
  - Simple script that exports users, organisations, spaces and roles from a given Cloudfoundry

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

- install\_deps.sh
  - Script to install various dependencies (eg awscli, cf-uaac)
    - Parameters: `[INSTALL_AWS]` 
    - Environmental Variables: `BOSH_CLI_VERSION BOSH_GITHUB_RELEASE_URL BOSH_CLI_RELEASE_TYPE CF_CLI_VERSION CF_GITHUB_RELEASE_URL
                                CF_CLI_RELEASE_TYPE NO_AWS PIP_VERSION_SUFFIX`

- install\_packages-EL.sh
  - Script to install various packages on Redhat/CentOS that then allow install\_deps.sh to run

- process\_cidrs.sh
  - Script to generate various network related config, eg CIDR sizes, static/reserved IP ranges
    - Parameters: `NETWORK_NAME CIDR`
    - Environmental Variables: `DEFAULT_DEFAULT_ROUTE_OFFEST DEFAULT_RESERVED_START_OFFSET DEFAULT_RESERVED_SIZE 
                                ${NETWORK_NAME}_DEFAULT_ROUTE_OFFSET ${NETWORK_NAME}_RESERVED_START_OFSET
                                ${NETWORK_NAME}_RESERVED_SIZE ${NETWORK_NAME}_STATIC_START_OFFSET
                                ${NETWORK_NAME}_STATIC_SIZE`

- setup\_cf-admin.sh
  - Create a basic Cloudfoundry admin user
    - Parameters: `DEPLOYMENT_NAME USERNAME EMAIL PASSWORD DONT_SKIP_SSL_VALIDATION`

- setup\_cf-elasticache-broker.sh
  - Upload the Cloudfoundry ElastiCache brokerA
    - Parameters:

- setup\_cf-orgspace.sh
  - Create a Cloudfoundry organisation and space
    - Parameters: `DEPLOYMENT_NAME [ORG_NAME] [SPACE_NAME]`

- setup\_cf-rds-broker.sh
  - Upload the Cloudfoundry RDS broker
    - Parameters: `DEPLOYMENT_NAME RDS_BROKER_DB_NAME RDS_BROKER_NAME CF_ORG`
    - Environmental Variables: `RDS_BROKER_DB_NAME RDS_BROKER_NAME DEFAULT_RDS_BROKER_DB_NAME DEFAULT_RDS_BROKER_NAME IGNORE_EXISTING
                                SERVICES_SPACE`

- setup\_cf-service-broker.sh
  - Generic script to setup a Cloudfoundry service broker
    - Parameters: `DEPLOYMENT_NAME [SERVICE_NAME] [SERVICE_USERNAME] [SERVICE_PASSWORD] [SERVICE_URL]`
    - Environmental Variables: `SERVICE_NAME SERVICE_USERNAME SERVICE_PASSWORD SERVICE_URL DONT_SKIP_SSL_VALIDATION IGNORE_EXISTING`

- setup\_cf.sh
  - Script that calls the variopus setup\_cf-\* scripts to configure a deployed Cloudfoundry instance
    - Parameters: `DEPLOYMENT_NAME [EMAIL_ADDRESS] [ORG_NAME] [TEST_SPACE] [DONT_SKIP_SSL_VALIDATION]`
    - Environmental Variables: `SKIP_TESTS`

- template.sh
  - Base template

- update\_aws\_cloudformation.sh
  - Update an existing set of AWS Cloudformation templates
    - Parameters: `Deployment_Name [AWS_Config_Prefix] [Hosted_Zone] [AWS_Region] [AWS_Access_Key_ID] [AWS_Secret_Access_Key]`
    - Environmental Variables: `HOSTED_ZONE, AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEBUG=true|false, AWS_PROFILE,
                                CLOUDFORMATION_DIR, IGNORE_MISSING_CONFIG=true|false SKIP_STACK_OUTPUTS_DIR, SKIP_MISSING,
                                SKIP_STACK_PREAMBLE_OUTPUTS_CHECK`

- upload\_components.sh
  - Upload various Cloudfoundry releases and stemcells.  Also records the uploaded versions
    - Parameters: `DEPLOYMENT_NAME CF_VERSION DIEGO_VERSION GARDEN_RUNC_VERSION CFLINUXFS2_VERSION CF_RABBITMQ_VERSION CF_SMOKE_TEST_VERSION`
    - Environmental Variables: `CF_VERSION DIEGO_VERSION GARDEN_RUNC_VERSION CFLINUXFS2_VERSION CF_RABBITMQ_VERSION CF_SMOKE_TEST_VERSION
                                CF_URL DIEGO_URL GARDEN_RUNC_URL CFLINUXFS2_URL CF_RABBITMQ_URL CF_SMOKE_TEST_URL`

- vendor\_update.sh
  - Interactive script to make the handling vendor'd Git repositories a little simplier
    Parameters: `[Vendored_Repo1..Vendored_RepoN]`
