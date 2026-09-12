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