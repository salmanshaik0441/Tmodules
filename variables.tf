variable "aws_region" {
  type = string
  description = "AWS Region to be used"
}

variable "aws_profile" {
  type = string
  description = "AWS profile to use as setup in ~/.aws/config"
}

variable "standard_tags" {
  description = "Standard tags that are used for all AWS resources"
  type = map(string)
}

variable "audits_username" {
  type = string
  description = "Username for the audits database"
}

variable "bevents_username" {
  type = string
  description = "Username for the business events database"
}

variable "snapshot_retention_periods" {
  type = string
  description = "Period (in days) to store db snapshot"
}

variable "db_engine_version" {
  type = string
  description = "DB Engine Version"
}

variable "perform_final_snapshot" {
  type = bool
  description = "Should Final snapshot be made before cluster is detroyed"
}

variable "instance_class" {
  type = string
  description = "Underlying EC2 type"
}

variable "vpc_id" {
  type = string
  description = "VPC ID"
}

variable "subnets" {
  type = list(string)
  description = "Subnet Id's for the region"
}

variable "storage_size" {
  type = number
  description = "The storage size to allocate to the db instance"
}

variable "multi_az" {
  description = "If set to true this enables multi-az for HA"
  type        = bool
}

variable "combine_audit_and_be_databases" {
  description = "If set to true, the Business Events database will not be created, only the Audits database for multi-use"
  type  = bool
}

variable "audit_db_prefix" {
  description = "Prefix for the names of the resources for the Audit DB"
  type = string
}

variable "be_db_prefix" {
  description = "Prefix for the names of the resources for the BE  DB"
  type = string
}

variable "audits_business_events_sg_name" {
  description = "Sg name for audit and business events"
  type = string
}

variable "kms_key_alias" {
  type = string
  description = "Alias name prefix for the RDS KMS key"
}

variable "account_role" {
  type          = string
}