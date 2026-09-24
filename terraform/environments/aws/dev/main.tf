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
  #codebuild_role_arn = module.cicd.codebuild_role_arn
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
  ecr_repository_arn     = module.ecr.repository_arn

  codebuild_project_name = var.codebuild_project_name
  ecr_repository_url     = module.ecr.repository_url
  aws_region             = var.aws_region
  environment            = var.environment
  github_repository      = var.github_repository
  github_branch          = var.github_branch
  codepipeline_name      = var.codepipeline_name
  artifact_bucket_name   = var.artifact_bucket_name

  eks_cluster_name = module.eks.cluster_name
  helm_chart_path  = "Helm/ott"
  helm_values_file = "Helm/ott/values-dev.yaml"

  deploy_codebuild_project_name = var.deploy_codebuild_project_name
  helm_release_name             = var.helm_release_name
  backend_namespace             = var.backend_namespace
  media_namespace               = var.media_namespace
}

# -----------------------------------------------------------------------------
# EKS aws-auth Configuration
# -----------------------------------------------------------------------------
# Maps the CodeBuild IAM role to a Kubernetes group so the CI/CD deployment
# process can authenticate and deploy workloads to the EKS cluster.
#
# The existing EKS node-role mapping is preserved.
# -----------------------------------------------------------------------------

resource "kubernetes_config_map_v1_data" "aws_auth" {

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = module.eks.node_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      },
      {
        rolearn  = module.cicd.deploy_codebuild_role_arn
        username = "ott-platform-codebuild"
        groups = [
          "ott-platform-deployer"
        ]
      }
    ])
  }

  force = true

  depends_on = [
    module.eks,
    module.cicd
  ]
}

# -----------------------------------------------------------------------------
# OTT Application Namespaces
# -----------------------------------------------------------------------------
# Kubernetes namespaces are managed by Terraform rather than Helm.
# Helm manages application resources inside these namespaces.
#
# Namespace layout:
#   ott-frontend -> Frontend workloads
#   ott-backend  -> Auth, Catalog, Stream workloads
#   ott-media    -> MinIO and media-processing workloads
# -----------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "ott_frontend" {
  metadata {
    name = "ott-frontend"
  }
}

resource "kubernetes_namespace_v1" "ott_backend" {
  metadata {
    name = var.backend_namespace
  }
}

resource "kubernetes_namespace_v1" "ott_media" {
  metadata {
    name = var.media_namespace
  }
}

# -----------------------------------------------------------------------------
# CodeBuild Deployment ClusterRole
# -----------------------------------------------------------------------------
# Grants the CodeBuild deployment group the Kubernetes permissions required
# to deploy and update the OTT Helm release.
#
# This is intentionally separate from the Stream service ClusterRole.
# -----------------------------------------------------------------------------

resource "kubernetes_cluster_role_v1" "ott_platform_deployer" {

  metadata {
    name = "ott-platform-deployer"
  }

  # Core Kubernetes API resources.
  rule {
    api_groups = [""]
    resources = [
      "configmaps",
      "secrets",
      "services",
      "serviceaccounts",
      "persistentvolumeclaims"
    ]
    verbs = [
      "get",
      "list",
      "watch",
      "create",
      "update",
      "patch",
      "delete"
    ]
  }

  # Workload resources.
  rule {
    api_groups = ["apps"]
    resources = [
      "deployments",
      "statefulsets"
    ]
    verbs = [
      "get",
      "list",
      "watch",
      "create",
      "update",
      "patch",
      "delete"
    ]
  }

  # RBAC resources created by the OTT Helm chart.
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources = [
      "clusterroles",
      "clusterrolebindings",
      "roles",
      "rolebindings"
    ]
    verbs = [
      "get",
      "list",
      "watch",
      "create",
      "update",
      "patch",
      "delete"
    ]
  }
}

# -----------------------------------------------------------------------------
# CodeBuild Deployment ClusterRoleBinding
# -----------------------------------------------------------------------------
# Connects the Kubernetes group assigned through aws-auth to the
# CodeBuild deployment ClusterRole.
# -----------------------------------------------------------------------------

resource "kubernetes_cluster_role_binding_v1" "ott_platform_deployer" {

  metadata {
    name = "ott-platform-deployer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.ott_platform_deployer.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "ott-platform-deployer"
    api_group = "rbac.authorization.k8s.io"
  }
}