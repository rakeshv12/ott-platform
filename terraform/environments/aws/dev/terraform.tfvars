aws_region = "us-east-1"
vpc_cidr   = "10.0.0.0/16"
availability_zones = [
  "us-east-1a",
  "us-east-1b"
]
project_name = "ott-platform"
environment  = "dev"

cluster_name       = "ott-platform-dev"
kubernetes_version = "1.33"

# EKS worker node configuration.
node_instance_type = "t3.medium"
node_min_size      = 2
node_desired_size  = 2
node_max_size      = 4


database_name           = "ottdb"
database_username       = "ottadmin"
database_instance_class = "db.t3.micro"
database_engine_version = "17"

redis_node_type      = "cache.t3.micro"
redis_engine_version = "7.1"

codepipeline_name     = "ott-platform-dev-pipeline"
artifact_bucket_name  = "ott-platform-dev-codepipeline-artifacts"
codebuild_project_name = "ott-platform-dev-build"
github_repository = "rakeshv12/ott-platform"
github_branch     = "main"