resource "aws_ssm_parameter" "secretpass" {
  name        = "/${var.domain}/${var.environment}/database/aws/auditevent/password"
  description = "The password for the aws audit event database"
  type        = "SecureString"
  value       = var.audit_event_rds_password
}

resource "aws_ssm_parameter" "secretuser" {
  name        = "/${var.domain}/${var.environment}/database/aws/auditevent/username"
  description = "The username for the aws audit event database"
  type        = "SecureString"
  value       = var.audit_event_rds_username
}

resource "aws_ssm_parameter" "secreturl" {
  name        = "/${var.domain}/${var.environment}/database/aws/auditevent/connectionstring"
  description = "The connection string for the aws event database."
  type        = "String"
  value       = var.audit_event_connection_string
}

resource "aws_ssm_parameter" "schema" {
  name        = "/${var.domain}/${var.environment}/database/aws/auditevent/schema"
  description = "Audit event database schema String"
  type        = "String"
  value       = var.audit_event_schema
}

resource "aws_ssm_parameter" "conf-es-index" {
  name        = "/${var.domain}/${var.environment}/lambda/aws/auditevent/es/index"
  description = "The index to be used on elasticsearch"
  type        = "String"
  value       = "audit-events-${var.environment}"
}

resource "aws_ssm_parameter" "conf-es-url" {
  name        = "/${var.domain}/${var.environment}/lambda/aws/auditevent/elasticsearch/url"
  description = "The absolute URL for elasticsearch"
  type        = "String"
  value       = "https://${var.elasticsearch_vpc_endpoint}:${var.elasticsearch_vpc_endpoint_port}"
}

resource "aws_iam_access_key" "iam_user_accesskey" {
  user = "${var.domain}-sqs-auditevents-write-${var.environment}"
}

output "accesskey_secret" {
  sensitive = true
  value = aws_iam_access_key.iam_user_accesskey.secret
}

output "accesskey_id" {
  value = aws_iam_access_key.iam_user_accesskey.id
}

resource "aws_secretsmanager_secret" "audits_sqs_secret_meta" {
  description = "The credentials used to connect to the Audit SQS queue"
  recovery_window_in_days = 0
  name_prefix = "${var.domain}-audit-sqs-"

  tags = {
    Name = "${var.domain}-audit-sqs-secret"
  }
}

resource "aws_secretsmanager_secret_version" "audits_sqs_secret" {
  depends_on = [aws_secretsmanager_secret.audits_sqs_secret_meta]
  secret_id = aws_secretsmanager_secret.audits_sqs_secret_meta.id
  secret_string = jsonencode({
    access_key_id = aws_iam_access_key.iam_user_accesskey.id
    access_key_secret = aws_iam_access_key.iam_user_accesskey.secret
  })
}
