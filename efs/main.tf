terraform {
  required_version = ">= 0.13.5"

  required_providers {
    aws = ">= 3.48.0"
  }
}

resource "aws_efs_file_system" "eks_efs_file_system" {
  encrypted  = var.efs_encrypted
  kms_key_id = var.kms_efs_key_arn
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
  tags = { Name = "${var.efs_name_prefix}efs" }
}

resource "aws_efs_backup_policy" "policy" {
  file_system_id = aws_efs_file_system.eks_efs_file_system.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "eks_efs_file_system_mount_target" {
  count           = length(var.mount_target_subnets)
  file_system_id  = aws_efs_file_system.eks_efs_file_system.id
  subnet_id       = var.mount_target_subnets[count.index]
  security_groups = [aws_security_group.allow_efs.id]
}

data "aws_vpc" "main" {
  id = var.vpc_id
}

resource "aws_security_group" "allow_efs" {
  name        = "${var.efs_name_prefix}allow_efs"
  description = "Allow EFS inbound traffic"
  vpc_id      = data.aws_vpc.main.id

  tags = {
    Name = "allow_efs"
  }
}

resource "aws_security_group_rule" "efs_secgroup_rules" {
  count          = length(data.aws_vpc.main.cidr_block_associations)
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.main.cidr_block_associations[count.index].cidr_block]
  security_group_id = aws_security_group.allow_efs.id
}
