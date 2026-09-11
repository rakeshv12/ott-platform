terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

  }

  backend "s3" {
    bucket = "ott-platform-terraform-state-use1-dev"
    key    = "aws/dev/terraform.tfstate"
    region = "us-east-1"
  }

}



provider "aws" {
  region  = var.aws_region
  profile = "ott-admin"
}