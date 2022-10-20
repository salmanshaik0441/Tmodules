
data "external" "npm_lambdabuild" {
		program = ["bash", "-c", <<EOT
(npm install && npm run build) >&2 && echo "{\"dest\": \"${var.audit_event_lamda_path}/dbfunction.zip\"}"
EOT
]
    working_dir = "${var.audit_event_lamda_path}/lambda"
}

data "archive_file" "lambda_zip_dir" {
	type        = "zip"
	output_path = "${var.audit_event_lamda_archive_path}/dbfunction.zip"
	source_dir  = "${var.audit_event_lamda_path}/lambda"
  depends_on = [data.external.npm_lambdabuild]
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.domain}-auditevents-lambdarole-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lamda_role_policy_read" {
  name = "${var.domain}-auditevents-lambdarole-policy-read-${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
                 "sqs:ReceiveMessage",
                 "sqs:DeleteMessage",
                 "sqs:SendMessage",
                 "sqs:GetQueueAttributes"
                 ],
        "Effect": "Allow",
        "Resource": [
          "${aws_sqs_queue.db_audit_queue.arn}",
          "${aws_sqs_queue.es_audit_queue.arn}",
          "${aws_sqs_queue.db_audit_queue_deadletter.arn}",
          "${aws_sqs_queue.es_audit_queue_deadletter.arn}"
          ]
      },
      {
        "Action": [
                 "ssm:GetParameters",
                 "ssm:GetParameter",
                 "ssm:DescribeParameters"
                 ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
        "Action": [
                 "kms:Encrypt",
                 "kms:Decrypt"
                 ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "lambda_role_policyadd_1" {
  role = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_security_group" "security_group" {
  name = "${var.domain}-auditevents-lambdasg-${var.environment}"
  description = "Allow acces to onprem DBs"

  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_s3_bucket" "b1" {
  bucket = "${var.domain}-auditevents-storage-v2-${var.environment}"
  tags = {
    Name = "${var.domain}-auditevents-storage-v2-${var.environment}"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
  bucket = aws_s3_bucket.b1.bucket
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_kms_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_object" "lambdacode" {
  bucket = aws_s3_bucket.b1.id
  key    = "${var.domain}-audit-sqs-lambda-file-${var.environment}"
  acl    = "private"
  source = "${var.audit_event_lamda_archive_path}/dbfunction.zip"
  etag = data.archive_file.lambda_zip_dir.output_md5
}

resource "aws_cloudwatch_log_group" "auditevents-db-loggroup" {
  name              = "/aws/lambda/${var.domain}-auditevents-sqslistener-${var.environment}"
  retention_in_days = 3
}

resource "aws_lambda_function" "auditevents-sqslistener" {
  function_name = "${var.domain}-auditevents-sqslistener-${var.environment}"
  handler = "handler.handler"
  source_code_hash = data.archive_file.lambda_zip_dir.output_base64sha256
  s3_bucket = aws_s3_bucket.b1.id
  s3_key = "${var.domain}-audit-sqs-lambda-file-${var.environment}"
  role = aws_iam_role.lambda_role.arn
  timeout = 120
  runtime = "nodejs12.x"
  memory_size = 512
  reserved_concurrent_executions = 6

  environment {
    variables = {
      DOMAIN = var.domain
      ENVIRONMENT = var.environment
      HOSTALIASES = "/tmp/hostaliases"
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
    Name = "${var.domain}-auditevents-sqslistener-${var.environment}"
  }

  depends_on = [aws_s3_bucket_object.lambdacode, aws_iam_role_policy_attachment.lambda_role_policyadd_1]
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.db_audit_queue.arn
  function_name    = aws_lambda_function.auditevents-sqslistener.arn

  maximum_batching_window_in_seconds = 180
  batch_size = 200
  enabled = true
}
