resource "aws_launch_template" "asg_lt" {
  count         = length(var.asg_configs)
  ebs_optimized = true
  image_id      = data.aws_ssm_parameter.ami.value

  instance_requirements {
    on_demand_max_price_percentage_over_lowest_price = 100
    spot_max_price_percentage_over_lowest_price      = 100
    vcpu_count {
      min = var.asg_configs[count.index].lt.instance_requirements.cpu_min
      max = var.asg_configs[count.index].lt.instance_requirements.cpu_min * 2
    }
    memory_mib {
      min = var.asg_configs[count.index].lt.instance_requirements.mem_min
      max = var.asg_configs[count.index].lt.instance_requirements.mem_min * 2
    }
  }
  name                   = "${var.cluster_name_prefix}${var.asg_configs[count.index].name_postfix}"
  tags                   = { Name : "${var.cluster_name_prefix}${var.asg_configs[count.index].name_postfix}" }
  update_default_version = true
  block_device_mappings {
    device_name = "/dev/xvda"
    no_device   = ""
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.data_volume_type
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.kms_root_vol_key_arn
    }
  }
  # Removed block_device_mappings from here because this was needed for kubelet and docker filesystems which are no longer needed and increasing default of root_volume
  # in variables to 100GB from 50GB
  iam_instance_profile {
    name = var.use_default_roles ? module.roles[0].role_workers_instance_profile.name : var.worker_inst_prof_name
  }
  monitoring {
    enabled = false
  }
  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [aws_security_group.eks_worker_sg.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge({ Name : "${var.cluster_name_prefix}${var.asg_configs[count.index].name_postfix}-${random_uuid.instance_random_id.result}" }, var.cluster_tags)
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge({ Name : "${var.cluster_name_prefix}${var.asg_configs[count.index].name_postfix}-${random_uuid.instance_random_id.result}" }, var.cluster_tags)
  }
  user_data = base64encode(
    templatefile("${path.module}/k8s/templates/userdata_setup.sh.tpl", {
      s3_bucket  = module.create_s3_bucket_userdata.bucket_uri
      node_type  = var.asg_configs[count.index].name_postfix
      aws_region = var.aws_region
      }
    )
  )
}

resource "aws_autoscaling_group" "asg" {
  count                     = length(var.asg_configs)
  default_cooldown          = 150
  desired_capacity          = var.asg_configs[count.index].min
  health_check_grace_period = var.asg_configs[count.index].health_check_grace_period
  health_check_type         = "EC2"
  lifecycle {
    ignore_changes = [desired_capacity, min_size, max_size]
  }
  max_instance_lifetime = var.asg_configs[count.index].max_instance_lifetime
  max_size              = var.asg_configs[count.index].max
  min_size              = var.asg_configs[count.index].min
  name                  = "${var.cluster_name_prefix}${var.asg_configs[count.index].name_postfix}"

  dynamic "mixed_instances_policy" {
    for_each = (var.asg_configs[count.index].lt.spot_enabled ? { "1" : 1 } : { "1" : 1 })
    content {
      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.asg_lt[count.index].id
          version            = aws_launch_template.asg_lt[count.index].latest_version
        }
      }

      dynamic "instances_distribution" {
        for_each = (var.asg_configs[count.index].lt.spot_enabled ? { "1" : 1 } : {})
        content {
          on_demand_base_capacity                  = 0
          on_demand_percentage_above_base_capacity = 0
          spot_allocation_strategy                 = "lowest-price"
          spot_instance_pools                      = 10
        }
      }
    }
  }
  enabled_metrics = ["GroupDesiredCapacity", "GroupTerminatingInstances"]
  dynamic "tag" {
    for_each = concat(
      [
        {
          key                 = "Name"
          value               = "${var.cluster_name_prefix}${var.asg_configs[count.index].name_postfix}"
          propagate_at_launch = false
        },
        {
          key                 = "k8s.io/cluster-autoscaler/enabled"
          value               = "true"
          propagate_at_launch = true
        },
        {
          key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
          value               = "owned"
          propagate_at_launch = true
        },
        {
          key                 = "k8s.io/cluster/${var.cluster_name}"
          value               = "owned"
          propagate_at_launch = true
        },
        {
          key                 = "kubernetes.io/cluster/${var.cluster_name}"
          value               = "owned"
          propagate_at_launch = true
        }
      ],
      [
        for tag_key, tag_value in var.cluster_tags :
        {
          key                 = tag_key,
          value               = tag_value,
          propagate_at_launch = false
        }
      ]
    )
    content {
      key                 = tag.value.key
      value               = tag.value.value
      propagate_at_launch = tag.value.propagate_at_launch
    }
  }
  target_group_arns   = [aws_lb_target_group.eks_alb_tg.arn]
  vpc_zone_identifier = var.instance_subnets
  depends_on          = [aws_launch_template.asg_lt]
}

data "aws_ssm_parameter" "ami" {
  name     = "/ami/vc/${var.aws_region}/os/AMZEKS/${var.k8s_version.minor}/${var.latest-ami ? "latestAMI" : "PreviousAMI"}"
  provider = aws.ami
}

resource "random_uuid" "instance_random_id" {

}

module "asg_instance_refresh" {
  count = var.do_asg_instance_refresh ? 1 : 0

  source                                    = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/aws-asg-instance-refresh.git?ref=1.0.0-5"
  cloudwatch_event_rule_name                = "${var.cluster_name}_asg_instance_refresh"
  cloudwatch_event_rule_schedule_expression = var.instance_refresh_cron
  lambda_role_description                   = "${var.cluster_name}_asg_instance_refresh"
  lambda_role_name                          = "${var.cluster_name}_asg_instance_refresh"
  lambda_name                               = "${var.cluster_name}_asg_instance_refresh"
  asg_arn                                   = [for asg in aws_autoscaling_group.asg : asg.arn]
  autoscaling_group_name                    = [for asg in aws_autoscaling_group.asg : asg.name]
  instance_refresh_min_healthy_percentage   = 100
  depends_on                                = [aws_autoscaling_group.asg]

}
