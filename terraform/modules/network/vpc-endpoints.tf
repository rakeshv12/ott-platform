# -----------------------------------------------------------------------------
# AWS Secrets Manager Interface VPC Endpoint
# -----------------------------------------------------------------------------
# What:
#   Creates private connectivity from resources inside the VPC to AWS Secrets
#   Manager.
#
# Why:
#   Private workloads such as EKS pods should be able to retrieve application
#   secrets without requiring Internet/NAT Gateway connectivity.
#
# Traffic flow:
#
#   Private EKS Workload
#          |
#          | HTTPS / TCP 443
#          v
#   Secrets Manager VPC Endpoint ENI
#          |
#          v
#   AWS Secrets Manager
#
# Security:
#   - Private DNS is enabled, so the normal Secrets Manager DNS name resolves
#     to the private endpoint inside the VPC.
#   - Traffic is restricted by the VPC endpoint security group.
#   - IAM permissions are still required to access individual secrets.
#
# Important:
#   The VPC endpoint provides NETWORK connectivity only.
#   It does NOT grant permission to read secrets.
#   IAM policies will control which workloads/users can access secrets.
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "secrets_manager" {

  # Attach the endpoint to our OTT platform VPC.
  vpc_id = aws_vpc.this.id

  # Secrets Manager uses an Interface Endpoint because AWS provides
  # private ENIs for this service inside our subnets.
  vpc_endpoint_type = "Interface"

  # Build the regional AWS service name dynamically.
  # This avoids hardcoding "us-east-1".
  service_name = "com.amazonaws.${data.aws_region.current.region}.secretsmanager"

  # Enable private DNS so applications can continue using the normal
  # AWS Secrets Manager hostname while traffic stays inside the VPC.
  private_dns_enabled = true

  # Create endpoint ENIs in every private subnet.
  # This provides connectivity from workloads in both Availability Zones.
  subnet_ids = [
    for subnet in aws_subnet.private : subnet.id
  ]

  # Reuse the security group created specifically for VPC endpoints.
  # HTTPS traffic on TCP/443 is allowed from inside the VPC.
  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-secrets-manager-endpoint"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}