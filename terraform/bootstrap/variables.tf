variable "aws_region" {
    description = "aws region for the ott platform"
    type = string
    default = "ap-south-1"

}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
}