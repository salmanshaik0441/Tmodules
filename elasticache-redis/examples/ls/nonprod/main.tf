
terraform {
  backend "s3" {
    bucket = "af-south-1-nonprod-tfstate"
    key    = "co-ls-ubuntu-elasticache-redis-qa.tfstate"
    # key    = "mendonis-refactor-ls-elastic-redis.tfstate"
    region = "af-south-1"        
    profile = "temp_sso_creds"
    dynamodb_table = "af-south-1-nonprod-tfstate-locks"
    encrypt = true
  }
}

module "ls_elasticache_redis" {
    source                      = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/elasticache-redis.git?ref=master"
    aws_profile                 = "temp_sso_creds"
    aws_region                  = "af-south-1"

    vpc_id                      = "vpc-05fe4369cad143dda"
    security_group_cidr         = ["10.0.0.0/8","100.65.0.0/21"]
    ingress_sg                  = []
    az_zones                    = ["af-south-1a", "af-south-1b"]

    node_instance_type          = "cache.t3.small"
    auto_failover               = true

    number_of_nodes             = 2
    subnet_ids                  = ["subnet-085c277409a869398","subnet-080d49513dd61b712"]
    installation_name           = "co-ls-ubuntu-elasticache-redis-qa"
    maintenance_window          = "sun:02:00-sun:04:00"
    snapshot_time               = "01:00-02:00"
    snapshot_retention          = 0
    default_user_id             = "ls-default-password-protected"
    generic_user_id             = "ls-generic-user"
    user_group_id               = "ls-elasticache-redis"

    standard_tags = {
        Name = "Lesotho_Elasticache_Redis"
        Environment = "QA"
        LMEntity = "VCZA"
        BU = "CBU"
        Project = "DXL Lesotho"
        ManagedBy = "DXLServiceEnablement@Vodasa.net-ISOWebsupportOnline@vodacom.co.za"
        Confidentiality = "C3"
        TaggingVersion = "v1.0"
        BusinessService = "VCOZA:Appl:ZA"
        ResourceManagementAutomation = "Terraform"
    }
}