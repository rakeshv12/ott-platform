output "ecr_repository_url" {
  description = "ECR repository URL for the Dev OTT platform"
  value       = module.ecr.repository_url
}

output "codebuild_role_arn" {
  description = "ARN of the IAM role used by CodeBuild"
  value       = module.cicd.codebuild_role_arn
}