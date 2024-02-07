terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.50"
    }
  }
}


provider "aws" {
  #checkov:skip=CKV_AWS_41:No credentials hardcoded into provider block
  region = local.REGION
}
