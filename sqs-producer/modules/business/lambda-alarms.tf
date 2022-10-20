resource "aws_cloudwatch_metric_alarm" "db_lambda_error_rate" {
  alarm_name = "${var.domain}-businessevents-sqslistener-db-error-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "5"
  datapoints_to_alarm = "5"
  metric_name = "Errors"
  namespace = "AWS/Lambda"
  period = "1800"
  statistic = "Average"
  threshold = "0.2"
  alarm_actions = [aws_sns_topic.business_events_sns_notifications.arn]
  alarm_description = "Monitoring for excessive Lambda failures"

  dimensions = {
    FunctionName = aws_lambda_function.businessevents-sqslistener.function_name
    ClientId = data.aws_caller_identity.current.account_id
  }

  tags = {
    Name = "${var.domain}-businessevents-sqslistener-db-error-${var.environment}"
  }
}

resource "aws_cloudwatch_metric_alarm" "es_lambda_error_rate" {
  alarm_name = "${var.domain}-businessevents-sqslistener-elastic-error-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "5"
  datapoints_to_alarm = "5"
  metric_name = "Errors"
  namespace = "AWS/Lambda"
  period = "1800"
  statistic = "Average"
  threshold = "0.2"
  alarm_actions = [aws_sns_topic.business_events_sns_notifications.arn]
  alarm_description = "Monitoring for excessive Lambda failures"

  dimensions = {
    FunctionName = aws_lambda_function.businessevents-sqslistener-elastic.function_name
    ClientId = data.aws_caller_identity.current.account_id
  }

  tags = {
    Name = "${var.domain}-businessevents-sqslistener-db-error-${var.environment}"
  }
}

resource "aws_sns_topic" "business_events_sns_notifications" {
  name = "${var.domain}-businessevents-sqs-${var.environment}-notifications"
}