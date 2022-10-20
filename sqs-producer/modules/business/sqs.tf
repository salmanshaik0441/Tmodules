resource "aws_sqs_queue" "db_business_queue" {
  name                      = "${var.domain}-business-events-queue-${var.environment}"
  delay_seconds             = 300
  max_message_size          = 262144
  message_retention_seconds = 172800
  visibility_timeout_seconds = 300
  receive_wait_time_seconds = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.db_business_queue_deadletter.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue" "db_business_queue_deadletter" {
  name                      = "${var.domain}-business-events-deadletter-queue-${var.environment}"
  delay_seconds             = 300
  max_message_size          = 262144
  message_retention_seconds = 1036800
  receive_wait_time_seconds = 10
}

resource "aws_sqs_queue" "es_business_queue" {
  name                      = "${var.domain}-business-events-elasticqueue-${var.environment}"
  delay_seconds             = 300
  max_message_size          = 262144
  message_retention_seconds = 172800
  visibility_timeout_seconds = 300
  receive_wait_time_seconds = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.es_business_queue_deadletter.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue" "es_business_queue_deadletter" {
  name                      = "${var.domain}-business-events-deadletter-elasticqueue-${var.environment}"
  delay_seconds             = 300
  max_message_size          = 262144
  message_retention_seconds = 1036800
  receive_wait_time_seconds = 10
}

resource "aws_iam_user" "sqs_write_user" {
  name = "${var.domain}-sqs-businessevents-write-${var.environment}"
  path = "/system/"
}

resource "aws_iam_user_policy" "business-sqs-write" {
  name = "${var.domain}-businessevents-sqs-policy-write-${var.environment}"
  user = aws_iam_user.sqs_write_user.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sqs:SendMessage",
      "Resource": [
        "${aws_sqs_queue.db_business_queue.arn}",
        "${aws_sqs_queue.es_business_queue.arn}"
      ]
    }
  ]
}
EOF
}
