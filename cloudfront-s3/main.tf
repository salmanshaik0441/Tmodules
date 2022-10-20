terraform {
  required_version = ">= 0.13.5"
}

data "aws_caller_identity" "current" {}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = var.standard_tags
  }
}

provider "aws" {
  alias  = "edgeregion"
  region = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = var.standard_tags
  }
}