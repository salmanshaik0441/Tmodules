resource "aws_ssm_parameter" "secretpass" {
  name        = "/${var.domain}/${var.environment}/database/aws/businessevent/password"
  description = "The password for the aws business event database"
  type        = "SecureString"
  value       = var.business_event_rds_password
}

resource "aws_ssm_parameter" "secretuser" {
  name        = "/${var.domain}/${var.environment}/database/aws/businessevent/username"
  description = "The username for the aws business event database"
  type        = "SecureString"
  value       = var.business_event_rds_username
}

resource "aws_ssm_parameter" "secreturl" {
  name        = "/${var.domain}/${var.environment}/database/aws/businessevent/connectionstring"
  description = "The connection string for the aws business event database. Without jdbc section."
  type        = "String"
  value       = var.business_event_connection_string
}

resource "aws_ssm_parameter" "schema" {
  name        = "/${var.domain}/${var.environment}/database/aws/businessevent/schema"
  description = "Business event database schema String"
  type        = "String"
  value       = var.business_event_schema
}

resource "aws_ssm_parameter" "conf-es-index" {
  name        = "/${var.domain}/${var.environment}/lambda/aws/businessevent/es/index"
  description = "The index to be used on elasticsearch"
  type        = "String"
  value       = "business-events-${var.environment}"
}

resource "aws_ssm_parameter" "conf-es-url" {
  name        = "/${var.domain}/${var.environment}/lambda/aws/businessevent/elasticsearch/url"
  description = "The absolute URL for elasticsearch"
  type        = "String"
  value       = "https://${var.elasticsearch_vpc_endpoint}:${var.elasticsearch_vpc_endpoint_port}"
}

resource "aws_iam_access_key" "iam_user_accesskey" {
  user = "${var.domain}-sqs-businessevents-write-${var.environment}"
}

output "accesskey_secret" {
  sensitive = true
  value = aws_iam_access_key.iam_user_accesskey.secret
}

output "accesskey_id" {
  value = aws_iam_access_key.iam_user_accesskey.id
}

resource "aws_secretsmanager_secret" "bevents_sqs_secret_meta" {
  description = "The credentials used to connect to the business events SQS queue"
  recovery_window_in_days = 0
  name_prefix = "${var.domain}-bevents-sqs-"

  tags = {
    Name = "${var.domain}-bevents-sqs-secret"
  }
}

resource "aws_secretsmanager_secret_version" "bevents_sqs_secret" {
  depends_on = [aws_secretsmanager_secret.bevents_sqs_secret_meta]
  secret_id = aws_secretsmanager_secret.bevents_sqs_secret_meta.id
  secret_string = jsonencode({
    access_key_id = aws_iam_access_key.iam_user_accesskey.id
    access_key_secret = aws_iam_access_key.iam_user_accesskey.secret
  })
}