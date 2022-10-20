
data "external" "npm_eslambdabuild" {
		program = ["bash", "-c", <<EOT
(npm install && npm run build) >&2 && echo "{\"dest\": \"${var.audit_event_lamda_path}/esfunction.zip\"}"
EOT
]
    working_dir = "${var.audit_event_lamda_path}/lambda"
}

data "archive_file" "eslambda_zip_dir" {
	type        = "zip"
	output_path = "${var.audit_event_lamda_archive_path}/esfunction.zip"
	source_dir  = "${var.audit_event_lamda_path}/eslambda"
  depends_on = [data.external.npm_eslambdabuild]
}


resource "aws_s3_bucket_object" "eslambdacode" {
  bucket = aws_s3_bucket.b1.id
  key    = "${var.domain}-audit-sqs-eslambda-file-${var.environment}"
  acl    = "private"
  source = "${var.audit_event_lamda_archive_path}/esfunction.zip"
  etag = data.archive_file.eslambda_zip_dir.output_md5
}

resource "aws_cloudwatch_log_group" "auditevents-es-loggroup" {
  name              = "/aws/lambda/${var.domain}-auditevents-sqslistener-elastic-${var.environment}"
  retention_in_days = 3
}

resource "aws_lambda_function" "auditevents-sqslistener-elastic" {
  function_name = "${var.domain}-auditevents-sqslistener-elastic-${var.environment}"
  handler = "handler.handler"
  source_code_hash = data.archive_file.eslambda_zip_dir.output_base64sha256
  s3_bucket = aws_s3_bucket.b1.id
  s3_key = "${var.domain}-audit-sqs-eslambda-file-${var.environment}" 
  role = aws_iam_role.lambda_role.arn
  timeout = 120
  runtime = "nodejs12.x"
  memory_size = 256
  reserved_concurrent_executions = 6

  environment {
    variables = {
      DOMAIN = var.domain
      ENVIRONMENT = var.environment
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.security_group.id]
  }

  timeouts {
    create = "10m"
  }

  tags = {
    Name = "${var.domain}-auditevents-sqslistener-elastic-${var.environment}"
  }

  depends_on = [aws_s3_bucket_object.eslambdacode, aws_iam_role_policy_attachment.lambda_role_policyadd_1]
}

resource "aws_lambda_event_source_mapping" "sqs_eslambda_trigger" {
  event_source_arn = aws_sqs_queue.es_audit_queue.arn
  function_name    = aws_lambda_function.auditevents-sqslistener-elastic.arn

  maximum_batching_window_in_seconds = 300
  batch_size = 50
  enabled = true
}
