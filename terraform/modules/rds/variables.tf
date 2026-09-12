variable "project_name" {
  description = "Name of the OTT platform project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS security group will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the RDS subnet group"
  type        = list(string)
}

variable "database_name" {
  description = "Name of the OTT application database"
  type        = string
}

variable "database_username" {
  description = "Master username for the PostgreSQL database"
  type        = string
}

variable "database_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "database_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
}