terraform {
  required_version = ">= 0.13.5"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = var.standard_tags
  }
}

resource "aws_security_group" "security-group" {
  name        = "${var.installation_name}-sg"
  description = "Allow access for redis cluster communication"
  vpc_id      = var.vpc_id

  # ingress {
  #   description = "Redis ingress"
  #   from_port   = 6379
  #   to_port     = 6379
  #   protocol    = "tcp"
  #   cidr_blocks = var.security_group_cidr
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.installation_name}-sg"
  }
}

resource "aws_security_group_rule" "redis_ingress" {
  count             = length(var.security_group_cidr) > 0 ? 1 : 0
  type              = "ingress"
  security_group_id = aws_security_group.security-group.id
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  cidr_blocks       = var.security_group_cidr
}

resource "aws_security_group_rule" "eks_cluster_sgs" {
  count                          = length(var.ingress_sg)
  type                           = "ingress"
  security_group_id              = aws_security_group.security-group.id
  from_port                      = 6379
  to_port                        = 6379
  protocol                       = "tcp"
  source_security_group_id       = var.ingress_sg[count.index]
}

resource "aws_elasticache_subnet_group" "subnet-group" {
  name        = "${var.installation_name}-subnet-group"
  subnet_ids  = var.subnet_ids

}

resource "random_password" "generic_user_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "default_user_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "aws_elasticache_user" "default-user" {
  user_id               = var.default_user_id
  user_name             = "default"
  access_string         = "on ~* +@all"
  engine                = "REDIS"
  passwords             = [random_password.default_user_password.result]
}

resource "aws_elasticache_user" "generic-user" {
  user_id               = var.generic_user_id
  user_name             = var.generic_user_id
  access_string         = "on ~* +@all -@admin -@dangerous +info"
  engine                = "REDIS"
  passwords             = [random_password.generic_user_password.result]
}

resource "aws_secretsmanager_secret" "generic_user_meta" {
  description = "The credentials used to connect to the elastic cache redis with generic user"
  recovery_window_in_days = 0
  name_prefix = "${var.installation_name}-"

  tags = {
    Name = "${var.installation_name}-secret"
  }
}

resource "aws_secretsmanager_secret_version" "generic_user_secret" {
  depends_on = [aws_secretsmanager_secret.generic_user_meta]
  secret_id = aws_secretsmanager_secret.generic_user_meta.id
  secret_string = jsonencode({
    user_name = var.generic_user_id
    passwords = aws_elasticache_user.generic-user.passwords
  })
}

resource "aws_elasticache_user_group" "user-group" {
  engine        = "REDIS"
  user_group_id = var.user_group_id
  user_ids      = [aws_elasticache_user.default-user.user_id, aws_elasticache_user.generic-user.user_id]
}

resource "aws_elasticache_replication_group" "replication-group" {
  automatic_failover_enabled    = var.auto_failover
  availability_zones            = var.az_zones
  replication_group_id          = var.installation_name
  description                   = "Replication group for dxl elasticache redis, cluster mode disabled"
  node_type                     = var.node_instance_type
  num_cache_clusters            = var.number_of_nodes
  parameter_group_name          = "default.redis6.x"
  engine_version                = "6.x"
  port                          = 6379
  security_group_ids            = [aws_security_group.security-group.id]
  depends_on                    = [aws_security_group.security-group]
  subnet_group_name             = aws_elasticache_subnet_group.subnet-group.name
  apply_immediately             = true
  maintenance_window            = var.maintenance_window
  snapshot_window               = var.snapshot_time
  snapshot_retention_limit      = var.snapshot_retention
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  user_group_ids                = [aws_elasticache_user_group.user-group.id]
}
