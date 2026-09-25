output "repository_url" {
  description = "URL of the ECR repository used to push OTT application container images"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository used by the OTT platform application images"
  value       = aws_ecr_repository.this.arn
}

output "base_images_repository_url" {
  description = "URL of the ECR repository used to store Docker base images"
  value       = aws_ecr_repository.base_images.repository_url
}

output "base_images_repository_arn" {
  description = "ARN of the ECR repository used to store Docker base images"
  value       = aws_ecr_repository.base_images.arn
}