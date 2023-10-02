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

  policy = templatefile("${path.module}/templates/iam-ssm-instance-profile-policy.json", {
    region = var.region
    ssm_output_s3_bucket_name = local.ssm_output_s3_bucket_name
  })
}
