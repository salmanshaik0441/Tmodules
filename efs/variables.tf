############### Variables used in the creation of EFS
variable "efs_encrypted" {
  description = "Whether the EFS volume should be encrypted or not"
  type        = bool
  default     = true
}

variable "kms_efs_key_arn" {
  description = "The arn of the kms key that will be used efs file system"
  type        = string
}

variable "efs_name_prefix" {
  type        = string
  description = "Name prefix for EFS resources and related resources"
}

variable "mount_target_subnets" {
  type        = list(string)
  description = "List of subnets to create mount targets in"
}

variable "vpc_id" {
  type        = string
  description = "ID of VPC of access points"
}
