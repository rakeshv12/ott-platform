# Creates an AWS CodeConnections connection to GitHub.
#
# Purpose:
# This allows AWS services such as CodePipeline to securely
# connect to our GitHub repository without storing a GitHub
# personal access token in Terraform or Jenkins.
#
# Important:
# Terraform creates the AWS-side connection first.
# The connection will initially be PENDING.
# We will authorize GitHub from the AWS Console afterward.

resource "aws_codeconnections_connection" "github" {
  name          = var.github_connection_name
  provider_type = "GitHub"
}

# IAM role assumed by AWS CodeBuild.
#
# CodeBuild needs an IAM role so it can access AWS services
# during the build without storing AWS access keys.

resource "aws_iam_role" "codebuild" {
    name = "${var.github_connection_name}-codebuild-role"

    # Allows the CodeBuild service to assume this role.
    assume_role_policy = jsonencode({
        Version = "2012-10-17"

        Statement = [
          {
            Effect = "Allow"
                Principal = {
                    Service = "codebuild.amazonaws.com"
                }

                Action = "sts:AssumeRole"
           
        }]
    })

}

# Allow CodeBuild to write its build logs to the dedicated
# CloudWatch Logs log group for this project.
resource "aws_iam_role_policy" "codebuild_logs" {
  name = "${var.github_connection_name}-codebuild-logs"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        # CodeBuild may create the project log group if it
        # does not already exist.
        Action = [
          "logs:CreateLogGroup"
        ]

        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/${var.codebuild_project_name}"
      },
      {
        Effect = "Allow"

        # CodeBuild creates a log stream and writes build events
        # inside the project-specific log group.
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/${var.codebuild_project_name}:*"
      }
    ]
  })
}

# Allow CodeBuild to read the source artifact delivered by CodePipeline.
resource "aws_iam_role_policy" "codebuild_s3" {
  name = "${var.github_connection_name}-codebuild-s3"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"

        # CodeBuild needs to read the CodePipeline artifact
        # stored in the S3 artifact bucket.
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]

        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      },
      {
        Effect = "Allow"

        # CodeBuild/CodePipeline integration may need bucket metadata.
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation"
        ]

        Resource = aws_s3_bucket.artifacts.arn
      }
    ]
  })
}


# Allows CodeBuild to authenticate with ECR and push
# the Docker images produced by our CI pipeline.
resource "aws_iam_role_policy" "codebuild_ecr" {
  name = "${var.github_connection_name}-codebuild-ecr"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]

        Resource = var.ecr_repository_arn
      }
    ]
  })
}

# AWS CodePipeline orchestrates the CI/CD workflow.
#
# Flow:
# GitHub → CodeConnections → CodePipeline → CodeBuild → ECR

# AWS CodePipeline orchestrates the complete AWS-native CI/CD workflow.
#
# Flow:
# GitHub → CodeConnections → CodePipeline → CodeBuild → ECR → EKS
#
# Pipeline V2 is used because it supports explicit Git-based triggers.
resource "aws_codepipeline" "ott" {
  name          = var.codepipeline_name
  role_arn      = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"

  # Automatically start the pipeline when code is pushed
  # to the configured GitHub branch.
  #
  # The trigger is handled by CodeConnections, so we do not
  # need to create a separate GitHub webhook or EventBridge rule.
  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      # This must match the name of the source action below.
      source_action_name = "GitHub"

      push {
        branches {
          # Only pushes to the configured branch trigger the pipeline.
          includes = [var.github_branch]
        }
      }
    }
  }

  # S3 stores artifacts exchanged between pipeline stages.
  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # ---------------------------------------------------------------------------
  # Source stage
  # ---------------------------------------------------------------------------
  # Retrieves source code from the GitHub repository through CodeConnections.
  stage {
    name = "Source"

    action {
      name             = "GitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codeconnections_connection.github.arn
        FullRepositoryId = var.github_repository
        BranchName       = var.github_branch
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Build stage
  # ---------------------------------------------------------------------------
  # Sends the source artifact to the Docker Build CodeBuild project.
  #
  # CodeBuild:
  # 1. Builds Auth, Catalog, Stream and Frontend images.
  # 2. Uses the private ECR base image.
  # 3. Pushes application images to ECR.
  stage {
    name = "Build"

    action {
      name            = "DockerBuild"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]

      configuration = {
        ProjectName = aws_codebuild_project.ott.name
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Deploy stage
  # ---------------------------------------------------------------------------
  # Sends the same source artifact to the dedicated deployment
  # CodeBuild project.
  #
  # The deployment project:
  # 1. Configures kubectl for EKS.
  # 2. Verifies cluster connectivity.
  # 3. Runs Helm upgrade/install.
  # 4. Deploys the application into EKS.
  stage {
    name = "Deploy"

    action {
      name            = "EKSDeploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]

      configuration = {
        ProjectName = aws_codebuild_project.deploy.name
      }
    }
  }

  # Standard resource tags.
  tags = {
    Name        = var.codepipeline_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


# AWS CodeBuild project.
#
# Purpose:
# CodeBuild is the build engine for our AWS-native CI/CD pipeline.
# CodePipeline will provide the source code to CodeBuild.
#
# The build will later:
# 1. Build the OTT Docker image.
# 2. Authenticate with Amazon ECR.
# 3. Push the image to ECR.
#
# privileged_mode is required because CodeBuild needs
# Docker-in-Docker capability to build container images.

resource "aws_codebuild_project" "ott" {
  name         = var.codebuild_project_name
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.ecr_repository_url
    }

    environment_variable {
      # ECR repository containing trusted Docker base images.
      # CodeBuild will use this instead of pulling node:20-alpine
      # directly from Docker Hub.
      name  = "BASE_IMAGE_REPOSITORY"
      value = var.base_images_repository_url
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.codebuild_project_name}"
      stream_name = "build"
    }
  }

  tags = {
    Name        = var.codebuild_project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}



# S3 bucket used by CodePipeline to temporarily store
# source and build artifacts between pipeline stages.
#
# This bucket is separate from the Terraform state bucket.
# Keeping them separate follows the principle of least privilege
# and prevents CI/CD operations from accessing Terraform state.

resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifact_bucket_name

  tags = {
    Name        = var.artifact_bucket_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Enable versioning so artifact object versions are retained.
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Prevent public access to CI/CD artifacts.
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt artifacts at rest using S3-managed encryption.
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# IAM role assumed by AWS CodePipeline.
#
# CodePipeline uses this role to interact with the AWS services
# required by the pipeline, such as CodeConnections, S3, and CodeBuild.

resource "aws_iam_role" "codepipeline" {
  name = "${var.codepipeline_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "codepipeline.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Permissions required by CodePipeline to:
# 1. Use the GitHub CodeConnections connection.
# 2. Read and write pipeline artifacts in S3.
# 3. Start and monitor the CodeBuild project.

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.codepipeline_name}-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "codeconnections:UseConnection"
        ]

        Resource = aws_codeconnections_connection.github.arn
      },
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ]

        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"

        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",
          "codebuild:StopBuild"
        ]

        Resource = [
          aws_codebuild_project.ott.arn,
          aws_codebuild_project.deploy.arn
        ] 
      }
    ]
  })
}

# Allow CodeBuild to obtain an authentication token for the EKS cluster.
#
# CodeBuild will use this permission when configuring kubectl
# against the target EKS cluster during the deployment stage.
resource "aws_iam_role_policy" "codebuild_eks" {
  name = "${var.github_connection_name}-codebuild-eks"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "eks:DescribeCluster"
        ]

        Resource = "*"
      }
    ]
  })
}

# IAM role assumed by the dedicated deployment CodeBuild project.
#
# This role is intentionally separate from the Docker build role.
# The build project creates and pushes images.
# The deploy project deploys those images to EKS.
resource "aws_iam_role" "deploy_codebuild" {
  name = "${var.deploy_codebuild_project_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "codebuild.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Allow the deployment CodeBuild project to write logs to CloudWatch.
resource "aws_iam_role_policy" "deploy_codebuild_logs" {
  name = "${var.deploy_codebuild_project_name}-logs"
  role = aws_iam_role.deploy_codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup"
        ]

        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/${var.deploy_codebuild_project_name}"
      },
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/${var.deploy_codebuild_project_name}:*"
      }
    ]
  })
}

# Allow the deployment CodeBuild project to obtain EKS
# cluster connection details for kubectl configuration.
resource "aws_iam_role_policy" "deploy_codebuild_eks" {
  name = "${var.deploy_codebuild_project_name}-eks"
  role = aws_iam_role.deploy_codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "eks:DescribeCluster"
        ]

        Resource = "*"
      }
    ]
  })
}

# Allow the deployment CodeBuild project to read the
# source artifact created by CodePipeline from S3.
#
# CodePipeline stores the source artifact in the artifact
# bucket before passing it to the Deploy CodeBuild project.
# CodeBuild therefore needs permission to download that
# artifact during the DOWNLOAD_SOURCE phase.
resource "aws_iam_role_policy" "deploy_codebuild_s3" {
  name = "${var.deploy_codebuild_project_name}-s3"
  role = aws_iam_role.deploy_codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]

        Resource = "arn:aws:s3:::${var.artifact_bucket_name}/*"
      }
    ]
  })
}

# Dedicated CodeBuild project for deploying the OTT platform to EKS.
#
# Unlike the Docker build project, this project does not need
# privileged Docker access. It receives the same source artifact
# from CodePipeline and runs Helm/kubectl deployment commands.
resource "aws_codebuild_project" "deploy" {
  name         = var.deploy_codebuild_project_name
  service_role = aws_iam_role.deploy_codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-deploy.yml"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = var.eks_cluster_name
    }

    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.ecr_repository_url
    }

    environment_variable {
      name  = "HELM_CHART_PATH"
      value = var.helm_chart_path
    }

    environment_variable {
      name  = "HELM_VALUES_FILE"
      value = var.helm_values_file
    }

    environment_variable {
      name  = "HELM_RELEASE_NAME"
      value = var.helm_release_name
    }

    environment_variable {
      name  = "BACKEND_NAMESPACE"
      value = var.backend_namespace
    }

    environment_variable {
      name  = "MEDIA_NAMESPACE"
      value = var.media_namespace
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.deploy_codebuild_project_name}"
      stream_name = "deploy"
    }
  }

  tags = {
    Name        = var.deploy_codebuild_project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
