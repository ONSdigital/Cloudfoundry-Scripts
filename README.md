# AWS/Bosh/Cloudfoundry Scripts

Various scripts to handle the life cycle of AWS Cloudformation, Bosh and Cloudfoundry.


- backup\_cloudfoundry-databases.sh
  - Run errands from https://github.com/ONSdigital/postgresql-databases-release.  This only backs up PostgreSQL
    databases.  Any database can be backed up, as long as the instance running the errand can reach the database
    - Parameters: Deployment Name

- backup\_cloudfoundry-s3.sh
  - Backup various internal Bosh/Cloudfoundry buckets to another S3 bucket.  This uses subdirectories that are named
    after
    the S3 source bucket
    -  Parameters: Deployment\_Name \[backup|restore'] [s3://destinaion|dir\_destination]

- bosh-cmd.sh
  - Helper script that pulls in the correct configuration to run the Bosh CLI. Any parameters after the *Deployment
    Name* are passed directly to the Bosh CLI
    - Parameters: Deployment\_Name [Parameter-1 ... Parameter-N]

- bosh-env.sh
  - Called by the various setup\_cf-\* scripts to set some required variables

- bosh-ssh.sh
  - Helper script to call the Bosh CLI with the correct options to allow SSH'ing onto a given host
    - Parameters: Deployment\_Name Destination SSH\_Host [Gateway\_User] \[Gateway\_Host\]

- bosh\_generate\_release.sh
  - Script to generate a release for upload onto Bosh
    - Parameters: Deployment\_Name Release\_Directory [Blob\_1 ... Blob\_N]

- ca-tool.sh
  - Generic script that creates CA and key pairs signed by the CA
    - Parameters: --ca-name|-C CA\_Name \[--new-ca|-N\] \[--update-ca\] \[--name|-n Name\] \[--update-name\] \[--key-size|-k\]
                  \[--not-basic-critical|-b\] \[--not-extended-critical|-c\]
                  \[--organisation|-o Organisation\_Part1 ... Organisation\_PartN\]
                  \[--generate-public-key|-p\] \[--generate-public-key-ssh-fingerprint|-f\]
                  \[--subject-alt-names|-s Subject\_Alt\_Name\_Part1 ...Subject\_Alt\_Name\_PartN\] \[--not-trusted|-t\]

- cf\_delete.sh
  - Simple script to login to Cloudfoundry and delete the named app
- cf\_push.sh
  - Simple script to login to Cloudfoundry and push the named app
- common-aws.sh
  - Common parts for the various AWS scripts
- common-bosh.sh
  - Common parts for the various Bosh scripts
- common.sh
  - Common parts for the various scripts
- create\_aws\_cloudformation.sh
  - Creates an AWS infrastructure using various Cloudformation Templates
- create\_dbs.sh
  - Reads the named Bosh manifest and creates the named databases
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
