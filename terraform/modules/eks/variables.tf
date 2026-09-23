# Project name used to create consistent resource names.
variable "project_name" {
  description = "Name of the OTT platform project"
  type        = string
}

# Environment identifies the deployment environment such as dev, UAT, or prod.
variable "environment" {
  description = "Deployment environment"
  type        = string
}

# Name of the EKS cluster.
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# Kubernetes version used by the EKS control plane.
variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

# VPC where the EKS cluster will be deployed.
variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

# Private subnets where the EKS cluster networking will be configured.
variable "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS cluster"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# EKS Worker Node Configuration
# -----------------------------------------------------------------------------

# EC2 instance type used by the EKS worker nodes.
variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
}

# Minimum number of worker nodes.
variable "node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
}

# Desired number of worker nodes.
variable "node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
}

# Maximum number of worker nodes.
variable "node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
}

