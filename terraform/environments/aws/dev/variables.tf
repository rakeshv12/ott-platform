variable "aws_region" {
  description = "aws region for the ott platform"
  type        = string
  default     = "ap-south-1"

}

variable "vpc_cidr" {
  description = "CIDR block for the AWS dev VPC"
  type        = string

}

variable "availability_zones" {
  description = "Availability Zones for the AWS dev environment"
  type        = list(string)
}

# Project name used for naming AWS resources.
variable "project_name" {
  description = "Name of the OTT platform project"
  type        = string
  default     = "ott-platform"
}

# Deployment environment.
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

# EKS cluster name
variable "cluster_name" {
  description = "Name of the DEV EKS cluster"
  type        = string

}

#kubernetes version for the EKS control plane.
variable "kubernetes_version" {
  description = "kubernetes version for the dev EKS cluster"
  type        = string
}


variable "node_instance_type" {
  description = "node instance type"
  type        = string
}
variable "node_min_size" {
  description = "node minimum size"
  type        = number

}
variable "node_desired_size" {
  description = "node desired size"
  type        = number

}
variable "node_max_size" {
  description = "node max size"
  type        = number

}

variable "database_name" {
  description = "Name of the OTT PostgreSQL database"
  type        = string
}

variable "database_username" {
  description = "Master username for the OTT PostgreSQL database"
  type        = string
}

variable "database_instance_class" {
  description = "RDS instance class for Dev"
  type        = string
}

variable "database_engine_version" {
  description = "PostgreSQL engine version for Dev"
  type        = string
}