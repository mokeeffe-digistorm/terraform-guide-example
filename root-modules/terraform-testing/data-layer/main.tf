# Terraform Cloud connection
#
# https://developer.hashicorp.com/terraform/tutorials/cloud/cloud-migrate
terraform {
  cloud {
    organization = "Digistorm"
    workspaces {
      name = "testing-data-layer"
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
      "ds:TerraformSource"         = "root-modules/terraform-testing/data-layer"
      "ds:TerraformCloudWorkspace" = "testing-data-layer"
      "ds:TerraformLayer"          = "data-layer"
      "ds:Environment"             = "testing"
      "ds:Application"             = "terraform-testing"
    }
  }
}

# The attribute `${data.aws_caller_identity.current.account_id}` will be current account number.
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "ssm_output_bucket" {
  bucket = local.ssm_output_s3_bucket_name
}

# Create Bitbucket private key in SSM Parameter Store
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter
resource "aws_ssm_parameter" "secret" {
  name        = var.bitbucket_private_key_ssm_parameter_path
  description = "Bitbucket deployment key"
  type        = "SecureString"
  value       = var.bitbucket_private_key
}

# Add IAM Policy for instances managed by SSM
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "policy" {
  name        = "SSMInstanceProfile"
  path        = "/"
  description = "Instance Profile for EC2 Instances managed by SSM"

  policy = templatefile("${path.module}/iam-policies/ssm-instance-profile.json", {
    region = var.region
    ssm_output_s3_bucket_name = local.ssm_output_s3_bucket_name
  })
}

# Activate Default Host Management Configuration (DHMC)
# https://docs.aws.amazon.com/systems-manager/latest/userguide/managed-instances-default-host-management.html#managed-instances-default-host-management-cli

# Create IAM Role
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "AWSSystemsManagerDefaultEC2InstanceManagementRole" {
  name               = "AWSSystemsManagerDefaultEC2InstanceManagementRole"
  assume_role_policy = templatefile("${path.module}/iam-policies/ssm-trust-relationship.json", {})
}
# Attache Policy to Role
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "AmazonSSMManagedEC2InstanceDefaultPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
  role       = aws_iam_role.AWSSystemsManagerDefaultEC2InstanceManagementRole.name
}
# Create SSM Service Setting
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_service_setting
resource "aws_ssm_service_setting" "default_host_management" {
  setting_id    = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:servicesetting/ssm/managed-instance/default-ec2-instance-management-role"
  setting_value = "service-role/AWSSystemsManagerDefaultEC2InstanceManagementRole"
}
