variable "standard_tags" {
  description = "Standard tags that are used for all AWS resources"
  type = map(string)
}

variable "project_prefix" {
  type = string
  description = "Project specific prefix to be used on tagging resources Ex OPCO-LS-S3-AppUI-StaticResources-Bucket."
}

variable "aws_region" {
  type = string
  default = "af-south-1"
}

variable "aws_profile" {
  type = string
  description = "The profile to use corresponding to ~/.aws/credentials"
}

variable "bucket_name" {
  type = string
  description = "Name of the bucket, normally he apex record of the domain, this can be any level from 1st sub domain of tld to nth sub-domain of tld"
}

variable "cicd_userarn" {
  type = string
  description = "The ARN record of the CICD system user, used to provide access for cicd tooling."
}

variable "acm_certificate" {
  type = string
  description = "The ARN of the acm viewer certificate, ARN has to be from region us-east-1."
}

variable "origin_name" {
  type = string
  description = "Name of the cloudfront origin."
}

variable "account_role" {
  type          = string
  description = "Account role running the tf script."
}

variable "allowed_country_codes" {
  type = list(string)
  description = "List of country codes that is allowed to access cloudfront distribution, only applicable for nonprod, can leave empty for prod"
}

variable "enable_geo_restriction" {
  description = "Enables geo restrictions for certain country codes, applicable for nonprod"
  type = bool
}

variable "waf_prefix" {
  type = string
  description = "Prefix used for waf acl resource creation."
}