# Terraform Cloud connection
#
# https://developer.hashicorp.com/terraform/tutorials/cloud/cloud-migrate
terraform {
  cloud {
    organization = "Digistorm"
    workspaces {
      name = "testing-compute-layer"
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
      "ds:TerraformSource"         = "root-modules/terraform-testing/compute-layer"
      "ds:TerraformCloudWorkspace" = "testing-compute-layer"
      "ds:TerraformLayer"          = "compute-layer"
      "ds:Environment"             = "testing"
      "ds:Application"             = "terraform-testing"
    }
  }
}

# Query AWS for VPC and subnet to be able to specify the subnet for our EC2 instance
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
data "aws_vpc" "my_vpc" {
  tags = {
    Name = "digistorm-dev-us-vpc"
  }
}
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet
data "aws_subnet" "my_private_subnet" {
  vpc_id            = data.aws_vpc.my_vpc.id
  availability_zone = "us-east-1a"

  tags = {
    Name = "digistorm-dev-us-public-sn-a"
  }
}

# Query AWS for the Ubuntu AMI
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ami
data "aws_ami" "amazon_linux_2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create EC2 Instance
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance.html
resource "aws_instance" "amazon_linux_2023" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnet.my_private_subnet.id

  tags = {
    Name                        = var.instance_name
    "ds:CodeDeployApplication" = "Deployment-Test"
    "ds:CodeDeployGroup"       = "Web-Server"
  }
}
