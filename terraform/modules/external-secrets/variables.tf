variable "aws_region" {
  description = "AWS region containing the secrets"
  type        = string
}

variable "namespace" {
  description = "Namespace for the SecretStore"
  type        = string
}

variable "database_name" {
  description = "Auth database name"
  type        = string
}

variable "rds_secret_arn" {
  description = "AWS-managed RDS credentials secret ARN"
  type        = string
}

variable "application_secret_arn" {
  description = "Application secret ARN containing JWT_SECRET"
  type        = string
}