variable "project_name" {
  description = "Name of the OTT platform project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Redis will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by Redis"
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache Redis node type"
  type        = string
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
}