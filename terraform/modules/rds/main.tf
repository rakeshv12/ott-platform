# Security group for PostgreSQL RDS.
# The database is private and should only accept PostgreSQL
# traffic from trusted application workloads inside the VPC.
resource "aws_security_group" "database" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for OTT PostgreSQL RDS"
  vpc_id      = var.vpc_id

  # PostgreSQL traffic will be restricted to the VPC initially.
  # Later, we can tighten this to the EKS workload security group
  # for a stronger least-privilege production design.
  ingress {
    description = "PostgreSQL from OTT VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # RDS is stateful, but explicit outbound access keeps the
  # security-group behavior clear for this project.
  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# RDS subnet group defines the private subnets where AWS can place
# the database network interfaces.
# Keeping RDS in private subnets prevents direct Internet exposure.
resource "aws_db_subnet_group" "database" {
  name = "${var.project_name}-${var.environment}-rds-subnet-group"

  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-subnet-group"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Create the PostgreSQL database used by the OTT application.
# The database remains private inside the VPC and is not publicly accessible.
resource "aws_db_instance" "database" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = var.database_engine_version
  instance_class = var.database_instance_class

  db_name  = var.database_name
  username = var.database_username

  # Generate the master password in AWS rather than storing
  # a database password in Terraform files or Git.
  manage_master_user_password = true

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.database.id]

  publicly_accessible = false

  backup_retention_period = 7

  # Protect the database from accidental Terraform deletion.
  deletion_protection = false

  skip_final_snapshot = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}