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

variable "eks_cluster_name" {
  description = "Name of the EKS cluster used for application deployment"
  type        = string
}

variable "helm_chart_path" {
  description = "Path to the Helm chart used for EKS deployment"
  type        = string
}

variable "helm_values_file" {
  description = "Path to the environment-specific Helm values file"
  type        = string
}

variable "deploy_codebuild_project_name" {
  description = "Name of the AWS CodeBuild project used for Kubernetes deployment"
  type        = string
}

variable "helm_release_name" {
  description = "Helm release name used to deploy the OTT platform"
  type        = string
}

variable "backend_namespace" {
  description = "Kubernetes namespace for OTT backend services"
  type        = string
}

variable "media_namespace" {
  description = "Kubernetes namespace for media services such as MinIO"
  type        = string
}

