variable "aws_region" {
  type = string
  description = "AWS Region to be used"
}

variable "aws_profile" {
  type = string
  description = "AWS profile to use as setup in ~/.aws/config"
}

variable "vpc_id" {
  type = string
  description = "VPC ID the elasticache cluster will reside in"
}

variable "security_group_cidr" {
  type = list(string)
  description = "The security group egress accepteable cidr range"
}

variable "standard_tags" {
  type = map(string)
}

variable "subnet_ids" {
  type = list(string)
  description = "Subnets the elasticache cluster will be placed in"
}

variable "az_zones" {
  type = list(string)
  description = "AZ zones for deployment"
}

variable "node_instance_type" {
  type = string
  description = "The EC2 instance type for the nodes to use"
}

variable "number_of_nodes" {
  type = number
  description = "Number of nodes to use in the cluster, the nodes are replicas and not shards"
}

variable "auto_failover" {
  type = bool
  description = "Should the cluster use auto failover. Not available for single instance clusters"
}

variable "installation_name" {
  type = string
  description = "Name for this installation, all resource names will be prefixed with it"
}

variable "maintenance_window" {
  type = string
  description = "Date of when maintenance can happen eg sun:02:00-sun:04:00"
}

variable "snapshot_time" {
  type = string
  description = "The time to run snapshots"
}

variable "snapshot_retention" {
  type = number
  description = "The number of days for which ElastiCache will retain automatic cache cluster snapshots before deleting them."
}

variable "ingress_sg" {
  type = list(string)
  description = "List of ingress security groups, values of eks_worker_sg in the eks cluster Module in security_groups.tf. (This is so that only the nodes in the worker group have access to redis)"
}

variable "default_user_id" {
  type = string
  description = "ID to use for the default user for redis"
}

variable "generic_user_id" {
  type = string
  description = "ID to use for the generic user for redis"
}

variable "user_group_id" {
  type = string
  description = "ID to use for the redis user group"
}
