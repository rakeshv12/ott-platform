variable "vpc_cidr" {
    description = "CIDR block for the AWS dev VPC"
    type = string
    
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones for the network"
  type        = list(string)
}