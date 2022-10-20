resource "aws_lb" "eks_master_alb" {
  count                         = var.eks_masters_in_private_range ? 1 : 0
  enable_deletion_protection    = true
  internal                      = true
  load_balancer_type            = "network"
  name                          = "${var.cluster_name_prefix}master-alb"
  #security_groups               = [aws_security_group.masters_alb_sg[0].id]
  subnets                       = length(var.lb_subnets) > 0 ? var.lb_subnets : var.subnets
  tags                          = { Name = "${var.cluster_name_prefix}master-alb" }
  idle_timeout                  = 300
}

resource "aws_lb_target_group" "eks_master_alb_tg" {
  count                         = var.eks_masters_in_private_range ? 1 : 0
  vpc_id                        = var.vpc_id
  deregistration_delay          = 2
  target_type                   = "ip"
  health_check {
    enabled                     = true
    healthy_threshold           = "2"
    interval                    = "30"
    protocol                   = "TCP"
 #   timeout                     = "30"
    unhealthy_threshold         = "2"
  }
  port                          = 443
  protocol                      = "TCP"
}


resource "aws_lb_listener" "eks_master_alb_listener_tls" {
  count                         = var.eks_masters_in_private_range ? 1 : 0
  load_balancer_arn             = aws_lb.eks_master_alb[0].arn
  port                          = 443
  protocol                      = "TCP"
  default_action {
    type                        = "forward"
    target_group_arn            = aws_lb_target_group.eks_master_alb_tg[0].arn
  }
  #certificate_arn               = var.default_lb_cert_arn
  #ssl_policy                    = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  depends_on                    = [aws_lb_target_group.eks_master_alb_tg[0]]
}

