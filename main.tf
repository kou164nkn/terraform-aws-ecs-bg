provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "ap-northeast-1"
}

data "aws_caller_identity" "self" {}

terraform {
  required_version = "~>1.0.0"
  backend "s3" {
    region  = "ap-northeast-1"
    bucket  = "kou-terraform-aws-eks"
    key     = "terraform.tfstate.aws.terraform-aws-ecs-bg"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3.46.0"
    }
  }
}
