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
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "digistorm-dev-us-vpc"
  }
}

# Configure Subnets (public|private|secure)
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "digistorm-dev-us-public-sn-${count.index + 1}"
  }
}
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "digistorm-dev-us-private-sn-${count.index + 1}"
  }
}
resource "aws_subnet" "secure_subnets" {
  count             = length(var.secure_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.secure_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "digistorm-dev-us-secure-sn-${count.index + 1}"
  }
}


# Configure Internet Gateway
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "digistorm-dev-us-ig"
  }
}


# Configure Public Route Table
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "digistorm-dev-public-route-table"
  }
}

# Configure Route Table Association
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_rt.id
}
