locals {
    vpc_id                                      = "vpc-0f198987d5b5b46e3"
    subnets                                     = ["subnet-01aa5ef2f846427b1"]
    aws_profile                                 = "default"
    kms_profile                                 = "default"
    aws_region                                  = "af-south-1"
	  account_role                                = "Online-ProdAdmin-Prod-Ltd"
    standard_tags = {
		Environment                   = "Development"
		LMEntity                      = "VCZA"
		BU                            = "CBU"
		Project                       = "DXL Extend Cluster for Summer"
		ManagedBy                     = "DXLServiceEnablement@Vodasa.net-ISOWebsupportOnline@vodacom.co.za"
		Confidentiality               = "C3"
		TaggingVersion                = "v1.0"
		BusinessService               = "VCOZA:Appl:ZA"
		ResourceManagementAutomation  = "Terraform"
	}
}

provider "aws" {
  region  = "af-south-1"
  profile = "default"
}

provider "aws" {
  region  = "af-south-1"
  profile = "default"
  alias = "kms"
}

terraform {
  backend "s3" {
    bucket = "af-south-1-prod-tfstate"
    key    = "summer-extend-cluster-PROD-nonprod.tfstate"
	# key    = "mendonis-refactor-ls.tfstate"
    region = "af-south-1"
    profile = "default"
    dynamodb_table = "af-south-1-prod-tfstate-locks"
    encrypt = true
  }
}

module dev_standalone {
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
    application_name                                        = "summer"
    asg_desired_capacity                                    = 3
    asg_min_size                                            = 2
    asg_max_size                                            = 5
    account_role                                            = local.account_role
    instance_type                                           = "t3.2xlarge"
    availability_zone                                       = "af-south-1a"
    salt_minion_prefix                                      = "PROD_"
    vpc_name_tag                                            = "Online-DXL-VPC-Prod"
    subnet_ids                                              = ["subnet-0e16895319cdb3546"]
    aws_region                                              = local.aws_region
    env_type                                                = "prod"
    storage_iops                                            = 0
    standard_tags                                           = local.standard_tags
    user_data_script_path                                   = "./user-data.sh"
    data_mount_size                                         = 80
    docker_lv_size                                          = 45
    kubelet_lv_size                                         = 30
    asg_names                                               = ["worker"]
}
