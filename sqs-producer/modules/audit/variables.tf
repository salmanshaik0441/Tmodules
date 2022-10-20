variable "environment" {
  description = "The logical environment name e.g. 'Production'"
  type = string
  default = ""
}

variable "domain" {
  type = string
  default = ""
}

variable "standard_tags" {
  description = "Standard tags that are used for all AWS resources"
  type = map(string)
}

variable "vpc_id" {
  type          = string
  description   = "VPC ID for the infrastructure to be provisioned in"
}

variable "aws_region" {
  type = string
  default = "af-south-1"
}

variable "aws_profile" {
  type = string
  default = ""
  description = "The profile to use corresponding to ~/.aws/credentials"
}

variable "account_role" {
  type          = string
  default       = ""
}

variable "audit_event_lamda_bucket_name" {
  type = string
  default = ""
}

variable "subnet_ids" {
  type          = list(string)
  description   = "Subnets for the infrastructure to use"
}

variable "elasticsearch_vpc_endpoint" {
  type = string
  default = ""
  description = "The URL for elasticsearch"
}

variable "elasticsearch_vpc_endpoint_port" {
  type = number
  description = "The port for elasticsearch"
}

variable "audit_event_rds_username" {
  type = string
  description = "Master username for audit event db"
}

variable "audit_event_rds_password" {
  type = string
  description = "Master passowrd for audit event db"
}

variable "audit_event_connection_string" {
  type = string
  description = "Connection string to Audit event db"
}

variable "audit_event_schema" {
  type = string
  description = "Schema of the Audit event db"
}

variable "audit_event_lamda_path" {
  type = string
  description = "Path to generated lamda snippets"
}

variable "audit_event_lamda_archive_path" {
  type = string
  description = "Output path for the lambda function archives"
}

