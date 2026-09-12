# Security group for Redis.
# Redis remains private and accepts connections only on the
# Redis port from workloads inside the VPC.
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Security group for OTT Redis"
  vpc_id      = var.vpc_id

  # Redis default port.
  # We will tighten this to the EKS workload security group
  # later as part of security hardening.
  ingress {
    description = "Redis from OTT VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-redis-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Define the private subnets where the Redis network interfaces
# will be placed. Redis remains inside the VPC and is not publicly exposed.
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-redis-subnet-group"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Create the Redis cache used by the OTT platform.
# Redis is deployed inside the private subnet group and is not
# directly reachable from the public Internet.
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"

  description = "Redis cache for OTT platform"

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type

  # Dev starts with a single primary node.
  # We can introduce replicas and Multi-AZ for UAT/Prod later.
  num_cache_clusters = 1

  port = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  # Encryption keeps Redis traffic protected inside the VPC.
  transit_encryption_enabled = true

  # Encryption at rest protects cached data stored by ElastiCache.
  at_rest_encryption_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-redis"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
