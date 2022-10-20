resource "aws_autoscaling_notification" "cluster_asg_node_event" {
  count = length(var.asg_configs)
  group_names = [
    aws_autoscaling_group.asg[count.index].name,
  ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = aws_sns_topic.cluster_ops_topic.arn
}


resource "aws_cloudwatch_metric_alarm" "alb_500_rate" {
  alarm_name                = "${var.cluster_name_prefix}alb-500-rate"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "5"
  datapoints_to_alarm       = "5"
  threshold                 = "5"
  alarm_actions             = [aws_sns_topic.cluster_ops_topic.arn]
  alarm_description         = "Monitoring rate of 500 alb failures"
  insufficient_data_actions = []


  metric_query {
    id          = "e1"
    expression  = "m1 / m2 * 100"
    label       = "Percentage of total errors"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    metric {
      metric_name = "HTTPCode_ELB_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "30"
      stat        = "Average"
      unit        = "Count"

      dimensions = {
        TargetGroup  = aws_lb_target_group.eks_alb_tg.arn_suffix
        LoadBalancer = aws_lb.eks_alb.arn_suffix
      }
    }
  }

  metric_query {
    id          = "m2"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = "30"
      stat        = "Average"
      unit        = "Count"

      dimensions = {
        TargetGroup  = aws_lb_target_group.eks_alb_tg.arn_suffix
        LoadBalancer = aws_lb.eks_alb.arn_suffix
      }
    }
  }

  tags = merge(
    { Name = "${var.cluster_name_prefix}alb-500-rate" },
    var.cluster_tags
  )
}


resource "aws_sns_topic" "cluster_ops_topic" {
  name = "${var.cluster_name_prefix}notifications"

  tags = merge(
    { Name = "${var.cluster_name_prefix}notifications" },
    var.cluster_tags
  )
}
