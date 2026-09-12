# -----------------------------------------------------------------------------
# VPC ID
# -----------------------------------------------------------------------------
# Exposes the VPC ID so other modules, such as EKS, can use the
# network created by this module.
# -----------------------------------------------------------------------------

output "vpc_id" {
    description     = "ID of the OTT platform VPC"
    value           = aws_vpc.this.id

}

# -----------------------------------------------------------------------------
# Private Subnet IDs
# -----------------------------------------------------------------------------
# Exposes all private subnet IDs created by the network module.
# EKS will use these subnets for worker-node and cluster networking.
# -----------------------------------------------------------------------------

output "private_subnet_ids" {
    description   = "ID of the private subnet"
    value         = [
        for subnet in aws_subnet.private : subnet.id
    ]

}