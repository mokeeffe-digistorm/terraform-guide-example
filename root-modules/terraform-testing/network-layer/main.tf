# Terraform Cloud connection
#
# https://developer.hashicorp.com/terraform/tutorials/cloud/cloud-migrate
terraform {
  cloud {
    organization = "Digistorm"
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
    Name = "digistorm-dev-us-vpc"
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
    Name = "digistorm-dev-us-public-sn-${each.key}"
  }
}
resource "aws_subnet" "private_subnets" {
  for_each          = local.private_subnet_cidrs
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = each.value
  availability_zone = local.availability_zones[each.key]

  tags = {
    Name = "digistorm-dev-us-private-sn-${each.key}"
  }
}
resource "aws_subnet" "secure_subnets" {
  for_each          = local.secure_subnet_cidrs
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = each.value
  availability_zone = local.availability_zones[each.key]

  tags = {
    Name = "digistorm-dev-us-secure-sn-${each.key}"
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
  subnet_ids = [ for s in aws_subnet.public_subnets : s.id]
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
    Name = "digistorm-dev-us-public-nacl"
  }
}
resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.main_vpc.id
  subnet_ids = [ for s in aws_subnet.private_subnets : s.id]
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
    Name = "digistorm-dev-us-private-nacl"
  }
}
resource "aws_network_acl" "secure_nacl" {
  vpc_id     = aws_vpc.main_vpc.id
  subnet_ids = [ for s in aws_subnet.secure_subnets : s.id]
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
    Name = "digistorm-dev-us-secure-nacl"
  }
}

# Add ingress/egress rules to secure subnet Network ACL to block traffic to/from public subnet
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "secure_ingress_nacl" {
  network_acl_id = aws_network_acl.secure_nacl.id
  protocol       = -1
  rule_number    = 90
  rule_action    = "deny"
  cidr_block     = "${var.subnet_first_two_octets}.0.0/18" # This CIDR covers all three public subnets
  from_port      = 0
  to_port        = 0
  egress         = false
}
resource "aws_network_acl_rule" "secure_egress_nacl" {
  network_acl_id = aws_network_acl.secure_nacl.id
  protocol       = -1
  rule_number    = 90
  rule_action    = "deny"
  cidr_block     = "${var.subnet_first_two_octets}.0.0/18" # This CIDR covers all three public subnets
  from_port      = 0
  to_port        = 0
  egress         = true
}


# Configure Internet Gateway
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "main_ig" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "digistorm-dev-us-ig"
  }
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
    Name = "digistorm-dev-public-route-table"
  }
}

# Configure Route Table Association
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "public_subnet_assoc" {
  for_each       = local.public_subnet_cidrs
  subnet_id      = aws_subnet.public_subnets[each.key].id
  route_table_id = aws_route_table.public_rt.id
}
