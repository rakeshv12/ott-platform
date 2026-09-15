output "repository_url" {
    description = "URL of the ECR repository used to push OTT container images"
    value = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
    description = "ARN of the ECR repository used by the OTT platform"
    value       = aws_ecr_repository.this.arn
}