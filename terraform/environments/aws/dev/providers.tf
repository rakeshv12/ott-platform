terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
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

# -----------------------------------------------------------------------------
# Existing EKS cluster data
# -----------------------------------------------------------------------------
# Reads the already-created EKS cluster so Terraform can configure
# the Kubernetes provider without creating another cluster.
# -----------------------------------------------------------------------------

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Retrieves a temporary authentication token for the EKS API.
data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

# -----------------------------------------------------------------------------
# Kubernetes Provider
# -----------------------------------------------------------------------------
# Uses the existing EKS API endpoint and CA certificate.
# -----------------------------------------------------------------------------

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}