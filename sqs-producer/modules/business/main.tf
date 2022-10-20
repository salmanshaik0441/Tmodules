terraform {
  required_version = ">= 0.12.0" 
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
}

data "aws_caller_identity" "current" {}