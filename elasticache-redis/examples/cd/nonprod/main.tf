
terraform {
  backend "s3" {
    bucket = "af-south-1-nonprod-tfstate"
    key    = "co-cd-ubuntu-elasticache-redis-nonprod.tfstate"
    # key    = "mendonis-refactor-ls-elastic-redis.tfstate"
    region = "af-south-1"        
    profile = "default"
    dynamodb_table = "af-south-1-nonprod-tfstate-locks"
    encrypt = true
  }
}

module "ls_elasticache_redis" {
    source                      = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/elasticache-redis.git?ref=feature/SE-10648-redis-user-and-user_group-terraform-script"
    aws_profile                 = "default"
    aws_region                  = "af-south-1"

    vpc_id                      = "vpc-0bd1a1f68dc67e037"
    security_group_cidr         = ["10.0.0.0/8","100.65.0.0/21"]
    ingress_sg                  = []
    az_zones                    = ["af-south-1a", "af-south-1b"]

    node_instance_type          = "cache.t3.small"
    auto_failover               = true

    number_of_nodes             = 2
    subnet_ids                  = ["subnet-01080fc17365984ec","subnet-0917b46cc7dc48815"]
    installation_name           = "co-cd-ubuntu-elasticache-dev-nonprod"
    maintenance_window          = "sun:02:00-sun:04:00"
    snapshot_time               = "01:00-02:00"
    snapshot_retention          = 0
    default_user_id             = "cd-default-password-protected"
    generic_user_id             = "cd-generic-user"
    user_group_id               = "cd-elasticache-redis"

    cluster_tags = {
        Name = "DRCongo_Elasticache_Redis"
        Environment = "QA"
        LMEntity = "VCZA"
        BU = "CBU"
        Project = "DXL DRC"
        ManagedBy = "DXLServiceEnablement@Vodasa.net-ISOWebsupportOnline@vodacom.co.za"
        Confidentiality = "C3"
        TaggingVersion = "v1.0"
        BusinessService = "VCOZA:Appl:ZA"
        ResourceManagementAutomation = "Terraform"
    }
}