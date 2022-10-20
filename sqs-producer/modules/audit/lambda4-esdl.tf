resource "aws_cloudwatch_log_group" "auditevents-esutil-loggroup" {
  name              = "/aws/lambda/${var.domain}-auditevents-esredriveutil-${var.environment}"
  retention_in_days = 1
}

resource "aws_lambda_function" "auditevents-esredriveutil" {
  function_name = "${var.domain}-auditevents-esredriveutil-${var.environment}"
  handler = "handler.handler"
  source_code_hash = data.archive_file.lambda_zip_dir.output_base64sha256
  s3_bucket = aws_s3_bucket.b1.id
  s3_key = "audit-sqs-dbutil-lambda-file-${var.environment}" 
  role = aws_iam_role.lambda_role.arn
  timeout = 240
  runtime = "nodejs12.x"
  memory_size = 256
  reserved_concurrent_executions = 1

  environment {
    variables = {
      FROMQUEUE = "https://${data.aws_vpc_endpoint.sqsendpoint.dns_entry[0].dns_name}/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.es_audit_queue_deadletter.name}"
      TOQUEUE = "https://${data.aws_vpc_endpoint.sqsendpoint.dns_entry[0].dns_name}/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.es_audit_queue.name}"
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
    Name = "${var.domain}-auditevents-esredriveutil-${var.environment}"
  }
  
  depends_on = [aws_s3_bucket_object.dbutillambdacode]
}
