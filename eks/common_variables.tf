############### This file is reserved for variables that should be defaults because 
############### they are shared accross all clusters and if changed would be changed for all 
############### clusters

variable "cross_account_id" {
  description = "The id of the account used to trigger codebuild projects for terraform"
  type        = string
  default     = "019523953090"
}

variable "ami_arn_role" {
  description = "The role used to get the latest AMI available"
  type        = string
  default     = "arn:aws:iam::971731176829:role/AMI_ID_Role"
}