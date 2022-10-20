terraform {
  backend "s3" {
    bucket = "af-south-1-prod-tfstate"
    key    = "co-ls-ubuntu-ms-audit-business-events-sqs-prod.tfstate"
    region = "af-south-1"
    profile = "default"
    dynamodb_table = "af-south-1-prod-tfstate-locks"
    encrypt = true
  }
}

module "ls_audit_business_event_sqs_producer" {
    source                              = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/sqs-producer.git?ref=master"

    #General
    aws_region                          = "af-south-1"
    aws_profile                         = "default"
    environment                         = "prod"
    domain                              = "co-ls-ubuntu"
    vpc_id                              = "vpc-0ca810fa7574b4db8"
    subnet_ids                          = ["subnet-027dfa4f39fdaa8b5","subnet-0d4194804201fa38b"]
    account_role                        = "Online-ProdAdmin-Prod-Ltd"
    elasticsearch_vpc_endpoint          = "https://vpc-opco-ls-dvpktanjjt2h23k5fktxgc7t7q.af-south-1.es.amazonaws.com"
    elasticsearch_vpc_endpoint_port     = 443
    standard_tags                       = {
      Environment = "Production"
      LMEntity = "VCZA"
      BU = "CBU"
      Project = "DXL Lesotho"
      ManagedBy = "DXLServiceEnablement@Vodasa.net ISOWebsupportOnline@vodacom.co.za"
      Confidentiality = "C3"
      TaggingVersion = "v1.0"
      BusinessService = "VCOZA:Appl:ZA"
      ResourceManagementAutomation = "Terraform"
    }

    #Audit events
    setup_audit_events                  = true
    audit_event_lamda_bucket_name       = "co-ls-ubuntu-auditevents-storage-prod"
    audit_event_rds_username            = "auditmaster"
    audit_event_rds_password            = ""
    audit_event_connection_string       = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=co-ls-rds-audits-oracle-primary.c2hvjyi4ladz.af-south-1.rds.amazonaws.com)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=AUDITS)))"
    audit_event_schema                  = "IAUDITFW"
    audit_event_lamda_path              = "../../../packages/audits"

    #Business events
    setup_business_events               = true
    business_event_lamda_bucket_name    = "co-ls-ubuntu-businesevents-storage-prod"
    business_event_rds_username         = "beventsmaster"
    business_event_rds_password         = ""
    business_event_connection_string    = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=co-ls-rds-bevents-oracle-primary.c2hvjyi4ladz.af-south-1.rds.amazonaws.com)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=BUSINESS)))"
    business_event_schema               = "ONLINE_BRF"
    business_event_lamda_path           = "../../../packages/bevents"
}