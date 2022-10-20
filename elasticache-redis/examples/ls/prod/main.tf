
terraform {
  backend "s3" {
    bucket = "af-south-1-prod-tfstate"
    key    = "co-ls-ubuntu-elasticache-redis-prod.tfstate"
    region = "af-south-1"        
    profile = "default"
    dynamodb_table = "af-south-1-prod-tfstate-locks"
    encrypt = true
  }
}

module "ls_elasticache_redis" {
    source                      = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/elasticache-redis.git?ref=master"    
    aws_profile                 = "default"
    aws_region                  = "af-south-1"

    vpc_id                      = "vpc-0ca810fa7574b4db8"
    security_group_cidr         = []
    ingress_sg                  = ["sg-0977abc9836baf59e"]
    az_zones                    = ["af-south-1a", "af-south-1b"]

    node_instance_type          = "cache.m5.large"
    auto_failover               = true

    number_of_nodes             = 2
    subnet_ids                  = ["subnet-027dfa4f39fdaa8b5", "subnet-0d4194804201fa38b"]
    installation_name           = "co-ls-ubuntu-elasticache-redis-prod"
    maintenance_window          = "sun:02:00-sun:04:00"
    snapshot_time               = "01:00-02:00"
    snapshot_retention          = 7

    standard_tags = {
        Name = "Lesotho_Elasticache_Redis"
        Environment = "Production"
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