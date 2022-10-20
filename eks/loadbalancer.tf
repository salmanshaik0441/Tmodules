resource "aws_lb" "eks_alb" {
  enable_deletion_protection    = true
  internal                      = true
  load_balancer_type            = "application"
  name                          = "${var.cluster_name_prefix}alb"
  security_groups               = length(var.alb_security_groups_override) > 0 ? var.alb_security_groups_override : [aws_security_group.alb_sg.id]
  subnets                       = length(var.lb_subnets) > 0 ? var.lb_subnets : var.subnets
  tags                          = { Name = "${var.cluster_name_prefix}alb" }
  idle_timeout                  = 300
}

resource "aws_lb_target_group" "eks_alb_tg" {
  vpc_id                        = var.vpc_id
  deregistration_delay          = 20
  health_check {
    enabled                     = true
    healthy_threshold           = "2"
    interval                    = "60"
    matcher                     = "200,404,302"
    path                        = "/"
    timeout                     = "30"
    unhealthy_threshold         = "5"
  }
  port                          = 30080
  protocol                      = "HTTP"
}

resource "aws_lb_listener" "eks_alb_listener_http" {
  load_balancer_arn             = aws_lb.eks_alb.arn
  port                          = "80"
  protocol                      = "HTTP"
  default_action {
    type                        = "redirect"
    redirect {
      status_code               = "HTTP_301"
      port                      = "443"
      protocol                  = "HTTPS"
    }
  }
}

resource "aws_lb_listener" "eks_alb_listener_tls" {
  load_balancer_arn             = aws_lb.eks_alb.arn
  port                          = 443
  protocol                      = "HTTPS"
  default_action {
    type                        = "forward"
    target_group_arn            = aws_lb_target_group.eks_alb_tg.arn
  }
  certificate_arn               = var.default_lb_cert_arn
  ssl_policy                    = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  depends_on                    = [aws_lb_target_group.eks_alb_tg]
}

resource "aws_lb_listener_certificate" "eks_alb_extra_certs" {
  count                         = length(var.extra_lb_certs_arns)
  depends_on                    = [aws_lb_listener.eks_alb_listener_tls]
  certificate_arn               = var.extra_lb_certs_arns[count.index]
  listener_arn                  = aws_lb_listener.eks_alb_listener_tls.arn
}


resource "aws_lb_listener_rule" "eks_alb_http_override" {
  count                   = length(var.http_override_hosts)
  listener_arn            = aws_lb_listener.eks_alb_listener_http.arn
  priority                = 100 + count.index

  action {
    type                  = "forward"
    target_group_arn      = aws_lb_target_group.eks_alb_tg.arn
  }

  condition {
    host_header {
      values              = [var.http_override_hosts[count.index]]
    }
  }
}