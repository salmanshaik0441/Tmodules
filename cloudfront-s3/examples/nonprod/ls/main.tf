module "ls_cloudfront_s3" {
    source                           = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/cloudfront-s3.git?ref=master"

    #General
    aws_region                       = "af-south-1"
    aws_profile                      = "default"
    account_role                     = "Online-ProdAdmin-NonProd-Ltd"
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
    bucket_name                      = "app.nonprod-ubuntu.vodacom.co.ls"
    cicd_userarn                     = "arn:aws:iam::581284919853:user/vf-aws-euwest-online-NonProd-EKS-svc"

    #Cloudfront

    #acm ARN has to be from region us-east-1
    acm_certificate                  = "arn:aws:acm:us-east-1:581284919853:certificate/f0afed22-c3c9-4df4-858a-91f2310aa213"
    origin_name                      = "co-ls-ubuntu-app-s3-origin"

    #waf and geoblocking
    allowed_country_codes            = ["LS", "IN", "ZA", "US"]
    enable_geo_restriction           = true
    waf_prefix                       = "co-ls-ubuntu"
}