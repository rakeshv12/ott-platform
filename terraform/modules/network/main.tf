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