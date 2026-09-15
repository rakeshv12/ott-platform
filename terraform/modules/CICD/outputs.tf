# ARN uniquely identifies the CodeConnections connection.
# The environment can use this ARN when configuring
# CodePipeline's GitHub source stage.

output "github_connection_arn" {
  description = "ARN of the AWS CodeConnections GitHub connection"
  value       = aws_codeconnections_connection.github.arn
}