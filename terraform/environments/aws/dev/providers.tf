terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

  }

  backend "s3" {
    bucket = "ott-platform-terraform-state-dev"
    key    = "aws/dev/terraform.tfstate"
    region = "ap-south-1"
  }

}



provider "aws" {
  region  = var.aws_region
  profile = "ott-admin"
}