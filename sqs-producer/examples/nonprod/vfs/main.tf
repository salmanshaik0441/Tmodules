terraform {
  backend "s3" {
    bucket = "af-south-1-vfs-nonprod-tfstate"
    key    = "vfs-ms-auditevents-sqs-nonprod.tfstate"
    region = "af-south-1"
    profile = "default"
    dynamodb_table = "af-south-1-vfs-nonprod-tfstate-locks"
    encrypt = true
  }
}

module "vfs_audit_business_event_sqs_producer" {
    source                              = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/sqs-producer.git?ref=master"

    #General
    aws_region                          = "af-south-1"
    aws_profile                         = "temp_sso_creds"
    environment                         = "nonprod"
    domain                              = "vfs"
    vpc_id                              = "vpc-0cbb110e8336e1f16"
    subnet_ids                          = ["subnet-0eb046df1b419eeea","subnet-08ca75857fa5442f5"]
    account_role                        = "VFSVASPlatformVFSVAZ-ProdAdmin-NonProd-Ltd"
    standard_tags                       = {
      Environment = "Quality Assurance"
      LMEntity = "VCZA"
      BU = "CBU"
      Project = "VFS"
      ManagedBy = "DXLServiceEnablement@Vodasa.net ISOWebsupportOnline@vodacom.co.za"
      Confidentiality = "C3"
      TaggingVersion = "v1.0"
      BusinessService = "VCOZA:Appl:ZA"
      ResourceManagementAutomation = "Terraform"
    }

    #Audit events
    setup_audit_events                  = true
    audit_event_lamda_bucket_name       = "co-za-vfs-auditevents-storage-nonprod"

    #Business events
    setup_business_events               = true
    business_event_lamda_bucket_name    = "co-za-vfs-businesevents-storage-nonprod"
}