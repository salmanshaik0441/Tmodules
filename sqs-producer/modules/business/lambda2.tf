
data "external" "npm_eslambdabuild" {
		program = ["bash", "-c", <<EOT
(npm install && npm run build) >&2 && echo "{\"dest\": \"${var.business_event_lamda_path}/eslambda/function.zip\"}"
EOT
]
    working_dir = "${var.business_event_lamda_path}/eslambda"
}

data "archive_file" "eslambda_zip_dir" {
	type        = "zip"
	output_path = "${var.business_event_lamda_archive_path}/eslambda/function.zip"
	source_dir  = "${var.business_event_lamda_path}/eslambda"
  depends_on = [data.external.npm_eslambdabuild]
}

resource "aws_s3_bucket_object" "eslambdacode" {
  bucket = aws_s3_bucket.b1.id
  key    = "${var.domain}-business-sqs-eslambda-file-${var.environment}"
  acl    = "private"
  source = "${var.business_event_lamda_archive_path}/eslambda/function.zip"
  etag = data.archive_file.eslambda_zip_dir.output_md5
}

resource "aws_cloudwatch_log_group" "businessevents-es-loggroup" {
  name              = "/aws/lambda/${var.domain}-businessevents-sqslistener-elastic-${var.environment}"
  retention_in_days = 3
}

resource "aws_lambda_function" "businessevents-sqslistener-elastic" {
  function_name = "${var.domain}-businessevents-sqslistener-elastic-${var.environment}"
  handler = "handler.handler"
  source_code_hash = data.archive_file.eslambda_zip_dir.output_base64sha256
  s3_bucket = aws_s3_bucket.b1.id
  s3_key = "${var.domain}-business-sqs-eslambda-file-${var.environment}" 
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
    Name = "${var.domain}-businessevents-sqslistener-elastic-${var.environment}"
  }
  
  depends_on = [aws_s3_bucket_object.eslambdacode, aws_iam_role_policy_attachment.lambda_role_policyadd_1]
}

resource "aws_lambda_event_source_mapping" "sqs_eslambda_trigger" {
  event_source_arn = aws_sqs_queue.es_business_queue.arn
  function_name    = aws_lambda_function.businessevents-sqslistener-elastic.arn

  maximum_batching_window_in_seconds = 180
  batch_size = 60
  enabled = true
}
