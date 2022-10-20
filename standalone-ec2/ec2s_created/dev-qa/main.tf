locals {
  vpc_id       = "vpc-0f38d1c2b8afd3612"
  subnets      = ["subnet-03e4e284375c94765", "subnet-04b633831a4f7cf5d"]
  aws_profile  = "temp_sso_creds"
  kms_profile  = "temp_sso_creds"
  aws_region   = "af-south-1"
  account_role = "Online-ProdAdmin-NonProd-Ltd"
  standard_tags = {
    Environment                  = "Development"
    LMEntity                     = "VCZA"
    BU                           = "CBU"
    Project                      = "DXL Extend Cluster"
    ManagedBy                    = "DXLServiceEnablement@Vodasa.net-ISOWebsupportOnline@vodacom.co.za"
    Confidentiality              = "C3"
    TaggingVersion               = "v1.0"
    BusinessService              = "VCOZA:Appl:ZA"
    ResourceManagementAutomation = "Terraform"
  }
}

provider "aws" {
  region  = "af-south-1"
  profile = "temp_sso_creds"
}

provider "aws" {
  region  = "af-south-1"
  profile = "temp_sso_creds"
  alias   = "kms"
}

terraform {
  backend "s3" {
    bucket = "af-south-1-nonprod-tfstate"
    key    = "summer-extend-cluster-devqa-nonprod.tfstate"
    # key    = "mendonis-refactor-ls.tfstate"
    region         = "af-south-1"
    profile        = "temp_sso_creds"
    dynamodb_table = "af-south-1-nonprod-tfstate-locks"
    encrypt        = true
  }
}

module "dev_standalone" {
  source         = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/standalone-ec2.git?ref=master"
  kms_policy_doc = "./kms-key-policy.json.tpl"
  ami_role_arn   = "arn:aws:iam::971731176829:role/AMI_ID_Role"
  is_k8node      = 1
  asg_notification_events = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
  application_name      = "summer-extend-cluster"
  asg_desired_capacity  = 1
  asg_min_size          = 1
  asg_max_size          = 2
  account_role          = local.account_role
  instance_type         = "t3.2xlarge"
  availability_zone     = "af-south-1a"
  salt_minion_prefix    = "QA_"
  vpc_name_tag          = "Online-VPC-NonProd"
  subnet_filter         = ["Online-VPC-NonProd-app-az1"]
  aws_region            = local.aws_region
  env_type              = "dev-qa"
  data_mount_size       = 20
  storage_iops          = 0
  standard_tags         = local.standard_tags
  user_data_script_path = "./user-data.sh"
}

module "instance_refresh" {
  source                                    = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/standalone-ec2.git?ref=master"
  cloudwatch_event_rule_name                = "summer-extend-cluster-dev-qa"
  cloudwatch_event_rule_schedule_expression = "cron(30 15 * * * *)"
  lambda_role_name                          = "summer-extend-cluster-dev-qa"
  lambda_role_description                   = "Role used for doing instance refresh on the asg"
  lambda_name                               = "summer-extend-cluster-dev-qa"
  autoscaling_group_name                    = module.dev_standalone.asg_name
  instance_refresh_min_healthy_percentage   = 90
}
