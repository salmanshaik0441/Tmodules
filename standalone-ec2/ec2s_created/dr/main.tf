locals {
    vpc_id                                      = "vpc-0f198987d5b5b46e3"
    subnets                                     = ["subnet-01aa5ef2f846427b1","subnet-00f760f644077dc8f"]
    aws_profile                                 = "temp_sso_creds"
    kms_profile                                 = "temp_sso_creds"
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
    key    = "summer-extend-cluster-DR-nonprod.tfstate"
	# key    = "mendonis-refactor-ls.tfstate"
    region = "af-south-1"
    profile = "default"
    dynamodb_table = "af-south-1-prod-tfstate-locks"
    encrypt = true
  }
}

module dev_standalone {
    source                                                  = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/standalone-ec2.git?ref=master"
    kms_policy_doc                                          = "/Users/ismaelmendonca/work/vodacom_repos/vodacom-terraform-modules/standalone-ec2/ec2s_created/dr/kms-key-policy.json.tpl"
    ami_role_arn                                            = "arn:aws:iam::971731176829:role/AMI_ID_Role"
    is_k8node                                               = 1
    asg_notification_events                                 = [
        "autoscaling:EC2_INSTANCE_LAUNCH",
        "autoscaling:EC2_INSTANCE_TERMINATE",
        "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
        "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
    ]
    application_name                                        = "summer"
    asg_desired_capacity                                    = 10
    asg_min_size                                            = 10
    asg_max_size                                            = 10
    account_role                                            = local.account_role
    instance_type                                           = "t3.2xlarge"
    availability_zone                                       = "af-south-1a"
    salt_minion_prefix                                      = "DR_"
    vpc_name_tag                                            = "Online-DXL-VPC-Prod"
    subnet_ids                                              = ["subnet-051caf0c2866e5275"]
    aws_region                                              = local.aws_region
    env_type                                                = "dr"
    storage_iops                                            = 0
    standard_tags                                           = local.standard_tags
    user_data_script_path                                   = "./user-data.sh"
    data_mount_size                                         = 80
    docker_lv_size                                          = 45
    kubelet_lv_size                                         = 30
    asg_names                                               = ["worker"]
}