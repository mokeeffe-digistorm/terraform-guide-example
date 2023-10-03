# Terraform Cloud connection
#
# https://developer.hashicorp.com/terraform/tutorials/cloud/cloud-migrate
terraform {
  cloud {
    organization = "Digistorm-Dev"
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
    Name = "digistorm-dev-us-private-sn-a"
  }
}

# Query AWS for Amazon Linux 2023 AMI
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
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
resource "aws_instance" "amazon_linux_2023" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnet.my_private_subnet.id
  iam_instance_profile = "DigistormInstanceProfile"

  tags = {
    Name                        = var.instance_name
    "ds:CodeDeployApplication" = "Deployment-Test"
    "ds:CodeDeployGroup"       = "Web-Server"
  }
}

# Create SSM Association - AWS-ApplyChefRecipes
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association
resource "aws_ssm_association" "run_chef_setup" {
  name = "AWS-ApplyChefRecipes"
  association_name = "${var.name_prefix}-run-chef-setup-recipe"

  parameters = {
    SourceType = "Git"
    SourceInfo = jsonencode({
      repository = var.chef_recipes_repository_name
      getOptions = "branch:${var.chef_recipes_repository_branch}"
      privateSSHKey = "{{ssm-secure:${var.bitbucket_private_key_ssm_parameter_path}}"
    })
    RunList: "recipe[ssm-test::setup]"
    WhyRun: "False"
    JsonAttributesContent = <<-EOT
      {
        "string-attribute": "TEST",
        "array-attribute": [
          "Another",
          "Value"
        ],
        "bool-attribute": true,
        "object-attribute": {
          "first": "first",
          "second": "second",
          "third": "third"
        }
      }
    EOT
    ChefClientVersion = "17"
    ComplianceSeverity = "Medium"
    ComplianceType = "Custom:Chef"
  }

  output_location {
    s3_bucket_name = local.ssm_output_s3_bucket_name
    s3_key_prefix = "server-provisioning"
    s3_region = var.region
  }

  targets {
    key    = "tag:ds:Environment"
    values = ["testing"]
  }
  targets {
    key    = "tag:ds:Application"
    values = ["terraform-testing"]
  }
}
