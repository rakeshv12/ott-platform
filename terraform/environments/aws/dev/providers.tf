terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
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

provider "helm" {
  kubernetes = {
    host = data.aws_eks_cluster.this.endpoint

    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.this.certificate_authority[0].data
    )

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", var.cluster_name,
        "--region", var.aws_region,
        "--profile", var.aws_profile
      ]
    }
  }
}