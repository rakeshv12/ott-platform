# -----------------------------------------------------------------------------
# EKS Cluster IAM Role
# -----------------------------------------------------------------------------
# This role is assumed by the AWS EKS service.
# It gives the EKS control plane the AWS permissions required to operate
# the Kubernetes cluster.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "eks_cluster" {

  # Role name is generated from project + environment so the same module
  # can be reused for dev, UAT, and production.
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  # ---------------------------------------------------------------------------
  # Trust Policy
  # ---------------------------------------------------------------------------
  # This answers:
  # "WHO is allowed to assume this IAM role?"
  #
  # Only the Amazon EKS service is trusted here.
  # ---------------------------------------------------------------------------
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-cluster-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# -----------------------------------------------------------------------------
# EKS Cluster Permissions
# -----------------------------------------------------------------------------
# This AWS-managed policy provides the permissions required by the EKS
# control plane to manage the AWS resources needed by the cluster.
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "eks_cluster" {

  role = aws_iam_role.eks_cluster.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# EKS Worker Node IAM Role
# -----------------------------------------------------------------------------
# This role is assumed by the EC2 instances that run as EKS worker nodes.
#
# The cluster role and node role have different responsibilities:
#
#   EKS Cluster Role → AWS-managed EKS control plane
#   Node Role        → EC2 worker nodes
#
# The node role allows worker nodes to perform the AWS operations they
# require, such as registering with the EKS cluster and pulling container
# images from ECR.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "eks_node" {

  # Generate the role name from project and environment so it can be reused
  # for Dev, UAT, and Production.
  name = "${var.project_name}-${var.environment}-eks-node-role"

  # ---------------------------------------------------------------------------
  # Trust Policy
  # ---------------------------------------------------------------------------
  # This answers:
  # "Who is allowed to assume this role?"
  #
  # EC2 instances use this role, so we trust the EC2 service.
  # ---------------------------------------------------------------------------

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-node-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# -----------------------------------------------------------------------------
# EKS Worker Node Permissions
# -----------------------------------------------------------------------------
# Allows the EC2 worker node to communicate with the EKS control plane.
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "eks_node_worker" {

  role = aws_iam_role.eks_node.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# -----------------------------------------------------------------------------
# ECR Read Permissions
# -----------------------------------------------------------------------------
# Worker nodes need permission to retrieve container images from Amazon ECR.
# This is required when Kubernetes starts a Pod whose image is stored in ECR.
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {

  role = aws_iam_role.eks_node.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

# -----------------------------------------------------------------------------
# Amazon VPC CNI Permissions
# -----------------------------------------------------------------------------
# The AWS VPC CNI plugin manages networking for Kubernetes Pods.
# It requires AWS permissions to manage ENIs/IP addresses used by Pods.
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "eks_node_cni" {

  role = aws_iam_role.eks_node.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}