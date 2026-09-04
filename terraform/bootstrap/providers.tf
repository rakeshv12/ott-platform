terraform {
    required_version = "~> 1.16"

    required_providers {
        aws = {
            source = "hashicorp/aws"
        }
    }
}

provider "aws" {
    region = "ap-south-1"
}