module "network" {
  source = "../../../modules/network"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}



# -----------------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------------
# Creates the EKS resources for the Dev environment.
# The EKS module will use the VPC and subnets created by our network module.
# -----------------------------------------------------------------------------

module "eks" {
  source = "../../../modules/eks"

  project_name = var.project_name
  environment  = var.environment

  # EKS cluster naming and Kubernetes version come from the Dev environment.
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # Consume values exposed by the Network module.
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  node_instance_type = var.node_instance_type
  node_min_size      = var.node_min_size
  node_desired_size  = var.node_desired_size
  node_max_size      = var.node_max_size
}

# Create the private ECR repository used to store
# container images for the Dev OTT platform.
module "ecr" {
  source = "../../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# Create the private PostgreSQL database for the Dev OTT platform.
# The RDS module receives networking and database configuration
# from the environment instead of hardcoding environment-specific values.
module "rds" {
  source = "../../../modules/rds"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  database_name           = var.database_name
  database_username       = var.database_username
  database_instance_class = var.database_instance_class
  database_engine_version = var.database_engine_version
}

# Create the private Redis cache for the Dev OTT platform.
# Networking and sizing are supplied by the Dev environment,
# while the reusable Redis implementation remains in the module.
module "redis" {
  source = "../../../modules/redis"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  node_type      = var.redis_node_type
  engine_version = var.redis_engine_version
}

# CI/CD infrastructure shared by the Dev environment.
# This creates the AWS-side connection that CodePipeline
# will later use to access our GitHub repository.

module "cicd" {
  source = "../../../modules/cicd"

  github_connection_name = "ott-platform-github"
  ecr_repository_arn         = module.ecr.repository_arn

  codebuild_project_name = var.codebuild_project_name
  ecr_repository_url = module.ecr.repository_url
  aws_region = var.aws_region
  environment = var.environment
  github_repository = var.github_repository
  github_branch     = var.github_branch
  codepipeline_name    = var.codepipeline_name
  artifact_bucket_name = var.artifact_bucket_name
}