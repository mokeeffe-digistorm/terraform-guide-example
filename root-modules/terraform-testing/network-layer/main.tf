# Terraform Cloud connection
#
# https://developer.hashicorp.com/terraform/tutorials/cloud/cloud-migrate
terraform {
  cloud {
    organization = "Digistorm-Dev"
    workspaces {
      name = "testing-network-layer"
    }
  }
}

# AWS Provider config. Set default tags for all AWS resources here.
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "ds:TerraformSource"         = "root-modules/terraform-testing/network-layer"
      "ds:TerraformCloudWorkspace" = "testing-network-layer"
      "ds:TerraformLayer"          = "network-layer"
      "ds:Environment"             = "testing"
      "ds:Application"             = "terraform-testing"
    }
  }
}

# Configure VPC
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# Configure Subnets (public|private|secure)
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
resource "aws_subnet" "public_subnets" {
  for_each          = local.public_subnet_cidrs
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = each.value
  availability_zone = local.availability_zones[each.key]

  tags = {
    Name = "${var.name_prefix}-public-sn-${each.key}"
  }
}
resource "aws_subnet" "private_subnets" {
  for_each          = local.private_subnet_cidrs
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = each.value
  availability_zone = local.availability_zones[each.key]

  tags = {
    Name = "${var.name_prefix}-private-sn-${each.key}"
  }
}
resource "aws_subnet" "secure_subnets" {
  for_each          = local.secure_subnet_cidrs
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = each.value
  availability_zone = local.availability_zones[each.key]

  tags = {
    Name = "${var.name_prefix}-secure-sn-${each.key}"
  }
}

# Rename default Network ACL to "DO NOT USE. DO NOT ADD RULES."
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_network_acl
resource "aws_default_network_acl" "default_nacl" {
  default_network_acl_id = aws_vpc.main_vpc.default_network_acl_id
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = {
    Name = "DO NOT USE. DO NOT ADD RULES."
  }
}

# Network ACL for each subnet
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl
resource "aws_network_acl" "public_nacl" {
  vpc_id     = aws_vpc.main_vpc.id
  subnet_ids = [for s in aws_subnet.public_subnets : s.id]
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = {
    Name = "${var.name_prefix}-public-nacl"
  }
}
resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.main_vpc.id
  subnet_ids = [for s in aws_subnet.private_subnets : s.id]
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = {
    Name = "${var.name_prefix}-private-nacl"
  }
}
resource "aws_network_acl" "secure_nacl" {
  vpc_id     = aws_vpc.main_vpc.id
  subnet_ids = [for s in aws_subnet.secure_subnets : s.id]
  # Add ingress/egress rules to secure subnet Network ACL to block traffic to/from public subnet
  ingress {
    protocol   = -1
    rule_no    = 90
    action     = "deny"
    cidr_block = "${var.subnet_first_two_octets}.0.0/18" # This CIDR covers all three public subnets
    from_port  = 0
    to_port    = 0
  }
  egress {
    protocol   = -1
    rule_no    = 90
    action     = "deny"
    cidr_block = "${var.subnet_first_two_octets}.0.0/18" # This CIDR covers all three public subnets
    from_port  = 0
    to_port    = 0
  }
  # Default ingress/egress rules
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = {
    Name = "${var.name_prefix}-secure-nacl"
  }
}


# Configure Internet Gateway
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "main_ig" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.name_prefix}-ig"
  }
}

# Configure Elastic IP For NAT Gateway
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
}
output "nat_gateway_ip" {
  value = aws_eip.nat_gateway_eip.public_ip
}
# Configure NAT Gateway in Public Subnet (A-Z "a")
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets["a"].id
  tags = {
    "Name" = "${var.name_prefix}-nat-gateway-a"
  }
}

# Configure Private Route Table for NAT Gateway
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "${var.name_prefix}-private-route-table"
  }
}
# Configure Private Route Table Association
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "private_subnet_assoc" {
  for_each       = local.private_subnet_cidrs
  subnet_id      = aws_subnet.private_subnets[each.key].id
  route_table_id = aws_route_table.private_rt.id
}

# Configure Public Route Table
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_ig.id
  }

  tags = {
    Name = "${var.name_prefix}-public-route-table"
  }
}
# Configure Public Route Table Association
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "public_subnet_assoc" {
  for_each       = local.public_subnet_cidrs
  subnet_id      = aws_subnet.public_subnets[each.key].id
  route_table_id = aws_route_table.public_rt.id
}


# Create Security Group for SSM VPC Endpoints
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "vpc_ssm" {
  name        = "vpc-ssm"
  description = "Allow VPC Endpoints for Systems Manager"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
#    cidr_blocks      = [aws_vpc.main_vpc.cidr_block]
#    ipv6_cidr_blocks = [aws_vpc.main_vpc.ipv6_cidr_block]
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "vpc-ssm"
  }
}


# Create VPC Endpoints to enable PrivateLink for Systems Manager on private subnet
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint
resource "aws_vpc_endpoint" "vpc_endpoint_interface" {
  count               = length(local.vpc_endpoint_services)
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = local.vpc_endpoint_services[count.index]
  subnet_ids          = [for s in aws_subnet.private_subnets : s.id]
  vpc_endpoint_type   = "Interface"

  security_group_ids = [
    aws_security_group.vpc_ssm.id,
  ]
}
resource "aws_vpc_endpoint" "vpc_endpoint_gateway" {
  vpc_id            = aws_vpc.main_vpc.id
  service_name      = local.vpc_endpoint_s3
  vpc_endpoint_type = "Gateway"
}
