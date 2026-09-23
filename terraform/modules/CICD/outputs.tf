# ARN uniquely identifies the CodeConnections connection.
# The environment can use this ARN when configuring
# CodePipeline's GitHub source stage.

output "github_connection_arn" {
  description = "ARN of the AWS CodeConnections GitHub connection"
  value       = aws_codeconnections_connection.github.arn
}

output "codebuild_role_arn" {
  description = "ARN of the IAM role used by CodeBuild"
  value       = aws_iam_role.codebuild.arn
}

output "deploy_codebuild_role_arn" {
  description = "ARN of the IAM role used by the CodeBuild deployment project"
  value       = aws_iam_role.deploy_codebuild.arn
}

