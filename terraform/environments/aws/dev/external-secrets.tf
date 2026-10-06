# Enables IAM authentication for workloads through EKS Pod Identity.
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.10-eksbuild.3"
}

# AWS identity used by External Secrets Operator.
resource "aws_iam_role" "external_secrets" {
  name = "${var.project_name}-${var.environment}-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}

# Allow ESO to read only the AWS-managed RDS credentials.
resource "aws_iam_role_policy" "external_secrets_rds" {
  name = "read-rds-secret"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [
        module.rds.master_user_secret_arn,
        aws_secretsmanager_secret.application.arn
      ]
    }]
  })
}

# Connect ESO's Kubernetes identity to its AWS IAM role.
resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy.external_secrets_rds
  ]
}
resource "aws_secretsmanager_secret" "application" {
  name                    = var.application_secret_name
  description             = "OTT application secrets"
  recovery_window_in_days = 7

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}