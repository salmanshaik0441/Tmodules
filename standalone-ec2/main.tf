provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = local.standard_tags
  }

}

provider "aws" {
  alias       = "ami"
  region      = var.aws_region
  assume_role {
    role_arn  = var.ami_role_arn
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  alias = "kms"
}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  application_role = "${var.application_name}_${var.env_type}_role"
  standard_tags    = var.standard_tags
  kms_profile      = "default"
}

# module ebs_volume_keys {
#   source                                                  = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/kms_key.git?ref=master"
# 	key_name												                        = "${var.application_name} volume key ${var.env_type}"
# 	key_description											                    = "Key for ${var.application_name} data volume"
# 	kms_profile												                      = local.kms_profile
# 	alias_name												                      = "eks-ls-prod-root-vol-ebs-key"
#   account_role                                            = var.account_role
# 	application_role									                      = local.application_role
#   cluster_tags                                            = local.standard_tags
#   restricted_access                                       = true
#   providers = {
#     aws = aws.kms
#   }
# }


resource "aws_sns_topic" "ops_topic" {
  name = "${var.application_name}-${var.env_type}"

  tags = merge(
  {Name : "${var.application_name}-standalone-${var.env_type}"},
  var.standard_tags
  )
}

data "aws_caller_identity" "current" {}
data "aws_elb_service_account" "main" {}

data "aws_vpc" "selected" {
  tags = {
    Name = var.vpc_name_tag
  }
}

data "aws_ssm_parameter" "ami" {
  # name = "/ami/vc/af-south-1/os/AMZ/2/latestAMI"
  name = "/ami/vc/af-south-1/os/AMZ/2/PreviousAMI"
  provider = aws.ami
}

resource "aws_security_group" "extend_security_group" {
  name_prefix = "${var.application_name}-sg-${var.env_type}-"
  description = "Security group to allow access to ec2 for ${var.application_name} ${var.env_type}"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port = 80
    to_port   = 32767
    protocol  = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port = 80
    to_port   = 32767
    protocol  = "tcp"
    cidr_blocks = ["100.0.0.0/8"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {Name : "${var.application_name}-Security-Group-${var.env_type}"}

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "node_role" {
  name = local.application_role
  path = "/"
  assume_role_policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [{
		"Action": "sts:AssumeRole",
		"Principal": {
			"Service": "ec2.amazonaws.com"
		},
		"Effect": "Allow"
	}]
}
EOF

  inline_policy {
    name = "volume_mount_inline"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume",
                "ec2:DetachVolume"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:volume/*",
                "arn:aws:ec2:*:*:instance/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVolumes",
                "ec2:DescribeVolumeAttribute"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
  }

  tags = {Name : "${var.application_name}-${var.env_type}_role"}

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "node_role_instance_profile" {
  path = "/"
  role = aws_iam_role.node_role.name
  lifecycle {
    create_before_destroy = true
  }
  tags = {Name : "${var.application_name}-instance-profile-${var.env_type}"}
}

# resource "aws_ebs_volume" "ebs_storage" {
#   availability_zone = "${var.availability_zone}"
#   kms_key_id        =  module.ebs_volume_keys.kms_key_arn
#   encrypted         =  "true"
#   size              =  var.data_mount_size
#   type              =  var.ebs_vol_type
#   iops              =  var.storage_iops
#   tags = merge(
#   {
#     Name = "${var.application_name}-volume-${var.env_type}"
#     Environment = var.env_type
#   },
#   var.standard_tags
#   )
# }

resource "aws_key_pair" "node_ssh_key" {
  key_name   = "${var.application_name}_node_access_key_${var.env_type}"
  public_key = file("${path.module}/keys/${var.env_type}.pub")
  tags = {Name : "${var.application_name} instance ssh key ${var.env_type}"}
}

resource "aws_autoscaling_group" "node_asg" {
  count = length(var.asg_names)
  name_prefix = join("",["${var.application_name}_node_${var.env_type}_","${var.asg_names[count.index]}"])
  launch_configuration = aws_launch_configuration.node_launchconfig.name
  desired_capacity = var.asg_desired_capacity
  min_size = var.asg_min_size
  max_size = var.asg_max_size
  vpc_zone_identifier = var.subnet_ids

  lifecycle {
    create_before_destroy = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
    }
  }

  tags = concat(
    [
      {
        key                                       = "Name"
        value                                     = join("-",["${var.env_type}-${var.application_name}","${var.asg_names[count.index]}"])
        propagate_at_launch                       = true
      }
    ],
    [
      for tag_key, tag_value in var.standard_tags :
        {
          key                                     = tag_key,
          value                                   = tag_value,
          propagate_at_launch                     = true
        }
    ],
  )
}

resource "aws_launch_configuration" "node_launchconfig" {
  name_prefix = "${var.application_name}_node_${var.env_type}_"
  image_id = data.aws_ssm_parameter.ami.value
  instance_type = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.node_role_instance_profile.name
  key_name = aws_key_pair.node_ssh_key.key_name

  ebs_block_device {
    device_name = "/dev/sdj"
    volume_size = var.data_mount_size
    volume_type = "standard"
    delete_on_termination = true
  }

  security_groups = [aws_security_group.extend_security_group.id]
  lifecycle {
    create_before_destroy = true
  }
  user_data = data.template_file.user_data_k8.rendered

}


data "template_file" "user_data_k8" {
#   count                  = var.is_k8node ? 1 : 0
#   template = file("${path.module}/templates/k8_node/user-data.sh")
  template = file(var.user_data_script_path)

  vars = {
    env_type                              = var.env_type
    data_mount_size                       = var.data_mount_size
    salt_minion_prefix                    = var.salt_minion_prefix
    aws_region                            = var.aws_region
    application_name                      = var.application_name
    docker_lv_size                        = var.docker_lv_size
    kubelet_lv_size                       = var.kubelet_lv_size
  }
}
