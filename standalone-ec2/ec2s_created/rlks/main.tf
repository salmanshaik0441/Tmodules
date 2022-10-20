locals {
  vpc_id                                      = "vpc-0312e96781046921c"
  subnets                                     = ["subnet-0b7b709bad68d3c4b"]
  aws_profile                                 = "default"
  kms_profile                                 = "default"
  aws_region                                  = "af-south-1"
  account_role                                = "DigitalDICHCZ-ProdAdmin-Prod-Ltd"
  standard_tags = {
    SecurityZone                              = "A"
    Environment                               = "Production"
    Project                                   = "OrbitCICD"
    ManagedBy                                 = "DXLServiceEnablement@vodacom.co.za"
    Confidentiality                           = "C3"
    TaggingVersion                            = "v2.0"
    BusinessService                           = "Digital Channels CICD:Appl:ZA"
    ResourceManagementAutomation              = "Terraform"
  }
}

provider "aws" {
  region  = "af-south-1"
  profile = "default"
  default_tags {
    tags = local.standard_tags
  }
}

provider "aws" {
  region  = "af-south-1"
  profile = "default"
  alias = "kms"
}

terraform {
  backend "s3" {
    bucket = "dxl-eks-terraform-prod"
    key    = "ucd-rlks.tfstate"
    region = "af-south-1"
    profile = "default"
    dynamodb_table = "dxl-eks-terraform-lock"
    encrypt = true
  }
}

module rlks_standalone {
    source                                                  = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/standalone-ec2.git?ref=master"
    kms_policy_doc                                          = "./kms-key-policy.json.tpl"
    ami_role_arn                                            = "arn:aws:iam::971731176829:role/AMI_ID_Role"
    is_k8node                                               = 1
    asg_notification_events                                 = [
        "autoscaling:EC2_INSTANCE_LAUNCH",
        "autoscaling:EC2_INSTANCE_TERMINATE",
        "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
        "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
    ]
    application_name                                        = "UCDLicenseServer"
    asg_desired_capacity                                    = 1
    asg_min_size                                            = 1
    asg_max_size                                            = 1
    account_role                                            = local.account_role
    instance_type                                           = "t3.small"
    availability_zone                                       = "af-south-1a"
    salt_minion_prefix                                      = ""
    vpc_name_tag                                            = "DigitalDICHCZ-VPC-Prod"
    subnet_ids                                              = ["subnet-0b7b709bad68d3c4b"]
    aws_region                                              = local.aws_region
    env_type                                                = "rlks"
    storage_iops                                            = 0
    standard_tags                                           = local.standard_tags
    user_data_script_path                                   = "./user-data.sh"
    data_mount_size                                         = 9
    docker_lv_size                                          = 7
    kubelet_lv_size                                         = 0
    asg_names                                               = ["ucd-license"]
}

resource "aws_iam_role" "dns_role" {
  name = "UCDLicenseServer_dns_role"
  path = "/"
  assume_role_policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [{
		"Action": "sts:AssumeRole",
		"Principal": {
			"AWS": "arn:aws:iam::019523953090:role/UCDLicenseServer_rlks_role"
		},
		"Effect": "Allow"
	}]
}
EOF

  inline_policy {
    name = "route53_inline"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "r53ChangeRecordSets",
            "Effect": "Allow",
            "Action": "route53:ChangeResourceRecordSets",
            "Resource": "arn:aws:route53:::hostedzone/*"
        },
        {
            "Sid": "r53ListZonesAndRecords",
            "Effect": "Allow",
            "Action": [
                "route53:ListResourceRecordSets",
                "route53:ListHostedZones",
                "route53:GetHostedZone"
            ],
            "Resource": "*"
        }
    ]
}
EOF
  }
}
