# Create a private Amazon ECR repository for OTT container images.
# ECR stores the Docker/OCI images that will be deployed to EKS.
resource "aws_ecr_repository" "this" {
    name = "${var.project_name}-${var.environment}"

  # Prevent accidental deletion of images when Terraform destroys
  # the repository. This is important because images are deployment artifacts.
  force_delete = false

  image_scanning_configuration {
    # Automatically scan images for known vulnerabilities when pushed.
    scan_on_push = true
  }

  image_tag_mutability = "MUTABLE"

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecr"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }


}

# Create a separate private ECR repository for Docker base images.
#
# The application Dockerfiles currently use node:20-alpine from Docker Hub.
# Keeping the base image in ECR removes the CodeBuild dependency on Docker Hub
# during normal application builds and avoids Docker Hub rate-limit failures.
resource "aws_ecr_repository" "base_images" {
  name = "${var.project_name}-base-images"

  # Base images are build dependencies, so keep them protected from
  # accidental Terraform destruction.
  force_delete = false

  image_scanning_configuration {
    # Scan base images for known vulnerabilities when they are pushed.
    scan_on_push = true
  }

  image_tag_mutability = "MUTABLE"

  tags = {
    Name        = "${var.project_name}-base-images-ecr"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Docker Base Images"
  }
}