terraform {
  backend "s3" {
    bucket = "af-south-1-prod-tfstate"
    key    = "co-ls-ubuntu-app-ui-prod.tfstate"
    region = "af-south-1"
    profile = "default"
    dynamodb_table = "af-south-1-prod-tfstate-locks"
    encrypt = true
  }
}

module "ls_cloudfront_s3" {
    source                           = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/cloudfront-s3.git?ref=master"

    #General
    aws_region                       = "af-south-1"
    aws_profile                      = "default"
    account_role                     = "Online-ProdAdmin-Prod-Ltd"
    project_prefix                   = "OPCO-LS"
    standard_tags                    = {
        Environment                  = "Production"
        LMEntity                     = "VCZA"
        BU                           = "CBU"
        Project                      = "DXL Lesotho"
        ManagedBy                    = "DXLServiceEnablement@Vodasa.net ISOWebsupportOnline@vodacom.co.za"
        Confidentiality              = "C3"
        TaggingVersion               = "v1.0"
        BusinessService              = "VCOZA:Appl:ZA"
        ResourceManagementAutomation = "Terraform"
    }

    #S3
    bucket_name                      = "app.ubuntu.vodacom.co.ls"
    cicd_userarn                     = "arn:aws:iam::025633447432:role/dxl_prod_crossaccount_cicd_svc"

    #Cloudfront 

    #acm ARN has to be from region us-east-1
    acm_certificate                  = "arn:aws:acm:us-east-1:025633447432:certificate/73e44644-95cf-484a-af85-79be3ba85e76"
    origin_name                      = "co-ls-ubuntu-app-s3-origin"

    #waf and geoblocking
    allowed_country_codes            = []
    enable_geo_restriction           = false
    waf_prefix                       = "co-ls-ubuntu"
}


