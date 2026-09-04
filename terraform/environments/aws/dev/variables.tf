variable "aws_region" {
  description = "aws region for the ott platform"
  type        = string
  default     = "ap-south-1"

}

variable "vpc_cidr" {
  description = "CIDR block for the AWS dev VPC"
  type        = string

}

