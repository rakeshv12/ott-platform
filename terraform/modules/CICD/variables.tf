variable "github_connection_name" {
    description = "Name of the AWS CodeCOnnections connection for GitHub"
    type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository that CodeBuild can push images to"
  type        = string
}

variable "codebuild_project_name" {
  description = "Name of the AWS CodeBuild project"
  type        = string
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository where Docker images will be pushed"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the CodeBuild project runs"
  type        = string
}

variable "environment" {
  description = "Deployment environment for the CI/CD resources"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/repository format"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch used by the CI/CD pipeline"
  type        = string
}

variable "codepipeline_name" {
  description = "Name of the AWS CodePipeline"
  type        = string
}

variable "artifact_bucket_name" {
  description = "S3 bucket used by CodePipeline for build artifacts"
  type        = string
}