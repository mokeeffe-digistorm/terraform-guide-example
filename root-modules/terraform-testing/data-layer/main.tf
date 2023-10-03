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


# Add IAM Policy for instances
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "instance_profile_policy" {
  name        = "DigistormInstanceProfilePolicy"
  path        = "/"
  description = "Instance Profile for EC2 Instances"

  policy = templatefile("${path.module}/iam-policies/ssm-instance-profile.json", {
    region                    = var.region
    ssm_output_s3_bucket_name = local.ssm_output_s3_bucket_name
  })
}
# Create IAM Role - Assume Role Policy for EC2
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_document
data "aws_iam_policy_document" "assume_role_ec2" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "ssm.amazonaws.com"
      ]
    }
    actions = ["sts:AssumeRole"]
  }
}
data "aws_iam_policy" "aws_ssm_managed_instance_core" {
  name = "AmazonSSMManagedInstanceCore"
}
data "aws_iam_policy" "aws_ssm_patch_association" {
  name = "AmazonSSMPatchAssociation"
}
# Create IAM Role
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "instance_profile_role" {
  name               = "DigistormInstanceProfile"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ec2.json
}
# Attach Policy to Role
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "instance_profile_attach" {
  role       = aws_iam_role.instance_profile_role.name
  policy_arn = aws_iam_policy.instance_profile_policy.arn
}
moved {
  from = aws_iam_role_policy_attachment.instance_profile_attach_ssm
  to = aws_iam_role_policy_attachment.instance_profile_attach_ssm_core
}
resource "aws_iam_role_policy_attachment" "instance_profile_attach_ssm_core" {
  role       = aws_iam_role.instance_profile_role.name
  policy_arn = data.aws_iam_policy.aws_ssm_managed_instance_core.arn
}
resource "aws_iam_role_policy_attachment" "instance_profile_attach_ssm_patch" {
  role       = aws_iam_role.instance_profile_role.name
  policy_arn = data.aws_iam_policy.aws_ssm_patch_association.arn
}
# Create Instance Profile for Role
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "DigistormInstanceProfile"
  role = aws_iam_role.instance_profile_role.name
}

# Activate Default Host Management Configuration (DHMC)
# https://docs.aws.amazon.com/systems-manager/latest/userguide/managed-instances-default-host-management.html#managed-instances-default-host-management-cli

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
resource "aws_iam_role" "AWSSystemsManagerDefaultEC2InstanceManagementRole" {
  name               = "AWSSystemsManagerDefaultEC2InstanceManagementRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ssm.json
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
