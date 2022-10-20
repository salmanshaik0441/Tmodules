variable "ami_role_arn" {
  type = string
  description = "The arn for the ami role that is used to get the hardened ami"
}

variable "asg_notification_events" {
  type = list(string)
  description = "The events that you want alarms for eg autoscaling:EC2_INSTANCE_LAUNCH"
}

variable "application_name" {
  type = string
  description = "What will this ec2/ec2's be used for"
}

variable "ebs_vol_type" {
  type = string
  description = "Type of ebs volume to use choises are standard, gp2, gp3, io1, io2, sc1 or st1"
  default = "gp2"
}

variable "asg_desired_capacity" {
  type = number
  description = "Desired number of ec2's to start up"
}

variable "asg_min_size" {
  type = number
  description = "ASG min size"
}

variable "asg_max_size" {
  type = number
  description = "ASG max size"
}

variable "account_role" {
  type = string
  description = "Account role for this account eg Online-ProdAdmin-Prod-Ltd"
}

variable "kms_policy_doc" {
    type = string
    description = "Absolute path to the policy template file for kms key policy"
  
}

variable "is_k8node" {
    type = number
    description = "Is this node to be added to an on prem kubernetes cluster, if yes then 1"
  
}

variable "user_data_script_path" {
  type = string
  description = "Absolute path to the user data script"
}

variable "standard_tags" {
  description = "Standard tags that are used for all AWS resources"
  type = map(string)
  
}

variable "availability_zone" {
  type = string
  default = "af-south-1a"
}

variable "storage_iops" {
  type = string
}

variable "instance_type" {
  type = string
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

variable "environment" {
    description = "Environment to add nodes to, need to match grain env_type in salt"
    type = map(string)
    default = {}
}

variable "env_type" {
    description = "Maps to environment type in salt"
    type = string
}

variable "salt_minion_prefix" {
    description = "The prefix added to the node which makes up the salt minion id, eg QA_ for dev-qa"
    type = string
}

variable "vpc_name_tag" {
  description = "Name tag associated with VPC"
  type = string
}

variable "data_mount_size" {
    description = "EBS volume size to be attached to ec2"
    type = number
    default = 80
}

variable "extend_k8_ebs_volume_size" {
    description = "EBS volume size to be attached to ec2"
    type = number
    default = 80
}

variable "docker_lv_size" {
    description = "Size of docker logical volume"
    type = number
    default = 50
}

variable "kubelet_lv_size" {
    description = "Size of kubelet logical volume"
    type = number
    default = 28
}

variable "asg_names" {
  description = "ASG names"
  type = list(string)
}

variable "subnet_ids" {
  description = "List of subnet id's that the nodes need to run in, be carefull not use the same subnet that another k8 cluster is using"
  type = list(string)
}
