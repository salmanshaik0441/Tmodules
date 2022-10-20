resource "aws_sqs_queue" "db_audit_queue" {
  name                      = "${var.domain}-audit-events-queue-${var.environment}"
  delay_seconds             = 300
  max_message_size          = 262144
  message_retention_seconds = 86400
  visibility_timeout_seconds = 300
  receive_wait_time_seconds = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.db_audit_queue_deadletter.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue" "db_audit_queue_deadletter" {
  name                      = "${var.domain}-audit-events-deadletter-queue-${var.environment}"
  delay_seconds             = 300
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

resource "aws_sqs_queue" "es_audit_queue" {
  name                      = "${var.domain}-audit-events-elasticqueue-${var.environment}"
  delay_seconds             = 300
  max_message_size          = 262144
  message_retention_seconds = 86400
  visibility_timeout_seconds = 300
  receive_wait_time_seconds = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.es_audit_queue_deadletter.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue" "es_audit_queue_deadletter" {
  name                      = "${var.domain}-audit-events-deadletter-elasticqueue-${var.environment}"
  delay_seconds             = 300
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

resource "aws_iam_user" "sqs_write_user" {
  name = "${var.domain}-sqs-auditevents-write-${var.environment}"
  path = "/system/"
}


resource "aws_iam_user_policy" "audit-sqs-write" {
  name = "${var.domain}-auditevents-sqs-policy-write-${var.environment}"
  user = aws_iam_user.sqs_write_user.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sqs:SendMessage",
      "Resource": [
        "${aws_sqs_queue.db_audit_queue.arn}",
        "${aws_sqs_queue.es_audit_queue.arn}"
      ]
    }
  ]
}
EOF
}
