# -----------------------------------------------------------------------------
# Amazon EKS Cluster
# -----------------------------------------------------------------------------
# Creates the managed Kubernetes control plane for the OTT platform.
#
# AWS manages the Kubernetes control-plane infrastructure such as:
# - Kubernetes API server
# - Scheduler
# - Controller components
# - etcd
#
# Our worker nodes will be added separately through an EKS Managed Node Group.
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "this" {

  # Cluster name is supplied by the environment rather than hardcoded.
  name = var.cluster_name

  # Kubernetes version is also supplied by the environment.
  version = var.kubernetes_version

  # IAM role created specifically for the EKS control plane.
  role_arn = aws_iam_role.eks_cluster.arn

  # ---------------------------------------------------------------------------
  # VPC configuration
  # ---------------------------------------------------------------------------
  # The EKS cluster is attached to our existing OTT VPC.
  # The subnet IDs will come from the network module.
  # ---------------------------------------------------------------------------

  vpc_config {

    # Existing VPC created by our network module.
    #vpc_id = var.vpc_id

    # EKS will use the private subnets for cluster networking.
    subnet_ids = var.private_subnet_ids

    # For Dev, we'll allow the Kubernetes API endpoint to be reachable
    # publicly so that we can administer the cluster from our workstation.
    #
    # We will restrict access later using endpoint access controls.
    endpoint_public_access = true

    # Private API access allows resources inside the VPC to communicate
    # with the Kubernetes API without going through the public Internet.
    endpoint_private_access = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


# -----------------------------------------------------------------------------
# EKS Managed Node Group
# -----------------------------------------------------------------------------
# Creates the EC2 worker nodes that will run our Kubernetes Pods.
#
# AWS manages the lifecycle of these nodes, including:
# - Node provisioning
# - Joining nodes to the EKS cluster
# - Rolling updates
# - Instance replacement
# -----------------------------------------------------------------------------
resource "aws_eks_node_group" "general" {
    cluster_name = aws_eks_cluster.this.name
    node_group_name = "${var.project_name}-${var.environment}-general"
    node_role_arn = aws_iam_role.eks_node.arn
    subnet_ids = var.private_subnet_ids
    instance_types = [
        var.node_instance_type
    ]
    scaling_config {
        min_size = var.node_min_size
        desired_size = var.node_desired_size
        max_size = var.node_max_size
    }
    update_config {
        max_unavailable = 1
    }

    tags = {
        Name    = "${var.project_name}-${var.environment}-eks-node"
        Environment = var.environment
        Managed  = "Terraform"
    }

    depends_on = [
        aws_eks_cluster.this
    ]



}