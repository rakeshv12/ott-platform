output "repository_url" {
    description = "URL of the ECR repository used to push OTT container images"
    value = aws_ecr_repository.this.repository_url
}