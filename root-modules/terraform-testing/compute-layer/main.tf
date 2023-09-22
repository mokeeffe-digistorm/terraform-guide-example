terraform {
  cloud {
    organization = "Digistorm"
    workspaces {
      name = "testing-compute-layer"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_vpc" "my_vpc" {
  tags = {
    Name = "digistorm-dev-us-vpc"
  }
}
data "aws_subnet" "my_private_subnet" {
  vpc_id     = data.aws_vpc.my_vpc.id
  availability_zone = "us-east-1a"

  tags = {
    Name = "digistorm-dev-us-public-sn-1"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ubuntu" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id   = data.aws_subnet.my_private_subnet.id

  tags = {
    Name = var.instance_name
  }
}
