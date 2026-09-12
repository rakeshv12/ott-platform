data "aws_region" "current" {

}
resource "aws_vpc" "this" {
    cidr_block = var.vpc_cidr
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "${var.project_name}-${var.environment}-vpc"
        Environment = var.environment
        ManageBy = "Terraform"
    }
}

resource "aws_subnet" "public"{
    for_each = {
        for index, az in var.availability_zones :
        az => {
            az = az
            cidr = cidrsubnet(var.vpc_cidr, 4, index)
        }
    }


    vpc_id                  = aws_vpc.this.id
    cidr_block              = each.value.cidr
    availability_zone       = each.value.az
    map_public_ip_on_launch = true
    
    tags = {
        Name        = "${var.project_name}-${var.environment}-public-${each.value.az}"
        Environment = var.environment
        ManagedBy    = "Terraform"

    }

} 

resource "aws_internet_gateway" "this"{
    vpc_id = aws_vpc.this.id

    tags = {
        Name            = "${var.project_name}-${var.environment}-igw"
        Environment     = var.environment
        ManagedBy       = "Terraform"
    }

}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.this.id

    tags = {
        Name            = "${var.project_name}-${var.environment}-public-rt"
        Environment     = var.environment
        ManagedBy       = "Terraform"

    }
}

resource "aws_route" "public_internet" {
    route_table_id              = aws_route_table.public.id 
    destination_cidr_block      = "0.0.0.0/0"
    gateway_id                  = aws_internet_gateway.this.id

}

resource "aws_route_table_association" "public" {
    for_each = aws_subnet.public

    subnet_id       = each.value.id
    route_table_id  = aws_route_table.public.id

}

resource "aws_subnet" "private" {
    for_each = {
        for index, az in var.availability_zones:
        az => {
            az = az
            cidr = cidrsubnet(var.vpc_cidr, 4, index+2)
        }
    }

    cidr_block      = each.value.cidr
    vpc_id          = aws_vpc.this.id
    availability_zone = each.value.az
    map_public_ip_on_launch = false

    tags = {
        Name            = "${var.project_name}-${var.environment}-private-${each.value.az}"
        Environment     = var.environment
        ManagedBy       = "Terraform"

    }
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.this.id

    tags = {
        Name            = "${var.project_name}-${var.environment}-private-rt"
        Environment     = var.environment
        ManagedBy       = "Terraform"

    }
}

resource "aws_route_table_association" "private" {
    for_each = aws_subnet.private

    subnet_id       = each.value.id
    route_table_id  = aws_route_table.private.id

}

resource "aws_vpc_endpoint" "s3" {
    vpc_id = aws_vpc.this.id
    vpc_endpoint_type = "Gateway"
    service_name = "com.amazonaws.${data.aws_region.current.region}.s3"
    route_table_ids = [
        aws_route_table.private.id
    ]

    tags = {
        Name            = "${var.project_name}-${var.environment}-s3-endpoint"
        Environment     = var.environment
        ManagedBy       = "Terraform"

    }
}

resource "aws_security_group" "vpc_endpoints" {
    name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
    vpc_id = aws_vpc.this.id
    ingress {
        description = "Allow HTTPS from workloads inside the VPC"
        from_port = 443
        to_port = 443
        protocol = "tcp"

        cidr_blocks = [var.vpc_cidr]
    }

    egress {
        description = "Allow outbound HTTPS traffic"
        from_port = 443
        to_port   = 443
        protocol  = "tcp"

        cidr_blocks = ["0.0.0.0/0"]

    }

    tags = {
        Name            = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
        Environment     = var.environment
        ManagedBy       = "Terraform"

    }

}

resource "aws_vpc_endpoint" "ecr_api" {
    vpc_id = aws_vpc.this.id
    vpc_endpoint_type = "Interface"
    service_name = "com.amazonaws.${data.aws_region.current.region}.ecr.api"
    private_dns_enabled = true
    subnet_ids = [
        for subnet in aws_subnet.private : subnet.id
    ]

    security_group_ids = [
        aws_security_group.vpc_endpoints.id
    ]

    tags = {
        Name            = "${var.project_name}-${var.environment}-ecr-api-endpoint"
        Environment     = var.environment
        ManagedBy       = "Terraform"

    }

}

resource "aws_vpc_endpoint" "ecr_dkr" {
    vpc_id = aws_vpc.this.id
    vpc_endpoint_type = "Interface"
    service_name = "com.amazonaws.${data.aws_region.current.region}.ecr.dkr"
    private_dns_enabled = true
    subnet_ids = [
    for subnet in aws_subnet.private : subnet.id
  ]
    security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecr-dkr-endpoint"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


# Allocate a public IPv4 address for the NAT Gateway.
# The NAT Gateway is placed in a public subnet so it can reach
# the Internet through the Internet Gateway.

resource "aws_eip" "nat" {
    domain = "vpc"

    tags = {
        Name        = "${var.project_name}-${var.environment}-nat-eip"
        Environment = var.environment
        ManagedBy   = "Terraform"

    }
}

# Create a NAT Gateway in the first public subnet.
# Private EKS nodes will use this NAT Gateway for outbound
# Internet traffic while remaining without public IP addresses.
resource "aws_nat_gateway" "this"{
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public[var.availability_zones[0]].id

    tags = {
        Name        = "${var.project_name}-${var.environment}-nat"
        Environment = var.environment
        ManagedBy   = "Terraform"
    }

    depends_on = [
        aws_internet_gateway.this
    ]
}


# Send outbound Internet traffic from private subnets
# through the NAT Gateway.
# This keeps EKS worker nodes private while allowing them
# to reach required external AWS/Internet endpoints.
resource "aws_route" "private_nat" {
    route_table_id  = aws_route_table.private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
}

    

