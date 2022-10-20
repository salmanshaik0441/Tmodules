terraform {
  required_version = ">= 0.12.0" 
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  alias   = "audit"

  default_tags {
    tags = merge(
      var.standard_tags,
      {Application = "AuditEvents"}
    )
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  alias   = "business"

  default_tags {
    tags = merge(
      var.standard_tags,
      {Application = "BusinessEvents"}
    )
  }
}

module "audit_event_sqs_producer" {
    count                               = var.setup_audit_events ? 1 : 0
    providers                           = { aws = aws.audit }

    source                              = "./modules/audit"
    aws_region                          = var.aws_region
    aws_profile                         = var.aws_profile
    environment                         = var.environment
    domain                              = var.domain
    vpc_id                              = var.vpc_id
    subnet_ids                          = var.subnet_ids
    account_role                        = var.account_role
    audit_event_lamda_bucket_name       = var.audit_event_lamda_bucket_name
    standard_tags                       = var.standard_tags

    elasticsearch_vpc_endpoint          = var.elasticsearch_vpc_endpoint
    elasticsearch_vpc_endpoint_port     = var.elasticsearch_vpc_endpoint_port
    audit_event_rds_username            = var.audit_event_rds_username
    audit_event_rds_password            = var.audit_event_rds_password
    audit_event_connection_string       = var.audit_event_connection_string
    audit_event_schema                  = var.audit_event_schema
    audit_event_lamda_path              = var.audit_event_lamda_path
    audit_event_lamda_archive_path      = var.audit_event_lamda_archive_path
}

module "business_event_sqs_producer" {
    count                               = var.setup_business_events ? 1 : 0
    providers                           = { aws = aws.business }

    source                              = "./modules/business"
    aws_region                          = var.aws_region
    aws_profile                         = var.aws_profile
    environment                         = var.environment
    domain                              = var.domain
    vpc_id                              = var.vpc_id
    subnet_ids                          = var.subnet_ids
    account_role                        = var.account_role
    business_event_lamda_bucket_name    = var.business_event_lamda_bucket_name
    standard_tags                       = var.standard_tags

    elasticsearch_vpc_endpoint          = var.elasticsearch_vpc_endpoint
    elasticsearch_vpc_endpoint_port     = var.elasticsearch_vpc_endpoint_port
    business_event_rds_username         = var.business_event_rds_username
    business_event_rds_password         = var.business_event_rds_password
    business_event_connection_string    = var.business_event_connection_string
    business_event_schema               = var.business_event_schema
    business_event_lamda_path           = var.business_event_lamda_path
    business_event_lamda_archive_path   = var.business_event_lamda_archive_path
}