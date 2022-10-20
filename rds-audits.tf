resource "random_password" "audit_password_generator" {
  length = 16
  min_lower = 5
  min_upper = 5
  min_numeric = 3
  special          = true
  override_special = "_%|#$%^&*()!"
}

resource "aws_secretsmanager_secret" "audits_secret_meta" {
  description = "The credentials used to connect to the Audit RDS instance"
  recovery_window_in_days = 0
  name_prefix = "${var.audit_db_prefix}-"

  tags = {
    Name = "${var.audit_db_prefix}-secret"
  }
}

resource "aws_secretsmanager_secret_version" "audits_secret" {
  depends_on = [aws_secretsmanager_secret.audits_secret_meta]
  secret_id = aws_secretsmanager_secret.audits_secret_meta.id
  secret_string = jsonencode({
    username = var.audits_username
    password = random_password.audit_password_generator.result
  })
}

resource "aws_db_instance" "audits_oracle_primary" {
  allocated_storage    = var.storage_size
  storage_type         = "gp2"
  engine               = "oracle-ee"
  engine_version       = var.db_engine_version
  instance_class       = var.instance_class
  name                 = "AUDITS"
  identifier           = "${var.audit_db_prefix}-oracle-primary"
  deletion_protection  = true
  storage_encrypted    = true
  kms_key_id           = aws_kms_key.root_ebs_key.arn
  username             = var.audits_username
  password             = jsondecode(aws_secretsmanager_secret_version.audits_secret.secret_string)["password"]  
  parameter_group_name = "default.oracle-ee-19"
  db_subnet_group_name = aws_db_subnet_group.audits_db_subnet_group.name
  skip_final_snapshot = var.perform_final_snapshot
  final_snapshot_identifier = "${var.audit_db_prefix}-final-snapshot"
  backup_window = "01:00-03:00"
  backup_retention_period = var.snapshot_retention_periods
  vpc_security_group_ids = toset([aws_security_group.audits_business_events_sg.id])  
  copy_tags_to_snapshot = true
  depends_on = [aws_db_subnet_group.audits_db_subnet_group, aws_security_group.audits_business_events_sg, aws_secretsmanager_secret_version.audits_secret]
  license_model = "bring-your-own-license"
  multi_az = var.multi_az

  tags = {
    Name = "${var.audit_db_prefix}-oracle-primary"
  }
}


resource "aws_db_subnet_group" "audits_db_subnet_group" {
  name = "${var.audit_db_prefix}-event-dbs-subnet-group"
  subnet_ids = var.subnets

  tags = {
    Name = "${var.audit_db_prefix}-event-dbs-subnet-group"
  }
}

resource "aws_security_group" "audits_business_events_sg" {
  description = "Security Group for RDS for business and audit events"
  ingress {
    cidr_blocks = ["10.0.0.0/8"]
    description = "SG Rule for DB Port ingress"
    from_port = 1521
    protocol = "TCP"
    to_port = 1521
  }
  name = var.audits_business_events_sg_name
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.audit_db_prefix}-sg"
  }
}
