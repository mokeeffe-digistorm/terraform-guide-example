# Terraform Cloud connection
#
# https://developer.hashicorp.com/terraform/tutorials/cloud/cloud-migrate
terraform {
  cloud {
    organization = "Digistorm-Dev"
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
  bucket        = local.ssm_output_s3_bucket_name
  force_destroy = var.ssm_output_s3_bucket_force_destroy
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


# Create IAM Policy for instances
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "instance_profile_policy" {
  name        = "DigistormInstanceProfilePolicy"
  path        = "/"
  description = "Instance Profile Policy for EC2 Instances"

  policy = templatefile("${path.module}/iam-policies/ssm-instance-profile.json", {
    account_id                = data.aws_caller_identity.current.account_id
    ssm_output_s3_bucket_name = local.ssm_output_s3_bucket_name
  })
}


# Activate Default Host Management Configuration (DHMC)
# https://docs.aws.amazon.com/systems-manager/latest/userguide/managed-instances-default-host-management.html#managed-instances-default-host-management-cli
#
# Create IAM Role - Assume Role Policy for SSM
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_document
data "aws_iam_policy_document" "assume_role_ssm" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
# Create IAM Role
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "DigistormSystemsManagerDefaultEC2InstanceManagementRole" {
  name               = "DigistormSystemsManagerDefaultEC2InstanceManagementRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ssm.json
}
# Attach Policies to Role
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "AmazonSSMManagedEC2InstanceDefaultPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
  role       = aws_iam_role.DigistormSystemsManagerDefaultEC2InstanceManagementRole.name
}
resource "aws_iam_role_policy_attachment" "AmazonSSMPatchAssociation" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMPatchAssociation"
  role       = aws_iam_role.DigistormSystemsManagerDefaultEC2InstanceManagementRole.name
}
resource "aws_iam_role_policy_attachment" "DigistormInstanceProfilePolicy" {
  policy_arn = aws_iam_policy.instance_profile_policy.arn
  role       = aws_iam_role.DigistormSystemsManagerDefaultEC2InstanceManagementRole.name
}
# Create SSM Service Setting
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_service_setting
resource "aws_ssm_service_setting" "default_host_management" {
  setting_id    = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:servicesetting/ssm/managed-instance/default-ec2-instance-management-role"
  setting_value = aws_iam_role.DigistormSystemsManagerDefaultEC2InstanceManagementRole.name
}
