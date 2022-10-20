output "asg_object" {
  value = [for asg in aws_autoscaling_group.node_asg : asg]
}
