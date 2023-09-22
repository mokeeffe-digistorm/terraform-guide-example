# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "tfe" {
  hostname = var.tfc_hostname
}

# Runs in this workspace will be automatically authenticated
# to AWS with the permissions set in the AWS policy.
#
# https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace
resource "tfe_workspace" "workspaces" {
  count        = length(var.tfc_workspaces)
  name         = "testing-${element(var.tfc_workspaces, count.index)}"
  organization = var.tfc_organization_name
  working_directory = "root-modules/terraform-testing/${element(var.tfc_workspaces, count.index)}"
  vcs_repo {
    github_app_installation_id = "ghain-SnFX2gGE4JVJ6KT7"
    identifier                 = "mokeeffe-digistorm/terraform-guide-example"
    ingress_submodules         = false
  }
}

# The following variables must be set to allow runs
# to authenticate to AWS.
#
# https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable
resource "tfe_variable" "enable_aws_provider_auth" {
  count        = length(var.tfc_workspaces)
  workspace_id = element(tfe_workspace.workspaces[*].id, count.index)

  key      = "TFC_AWS_PROVIDER_AUTH"
  value    = "true"
  category = "env"

  description = "Enable the Workload Identity integration for AWS."
}

resource "tfe_variable" "tfc_aws_role_arn" {
  count        = length(var.tfc_workspaces)
  workspace_id = element(tfe_workspace.workspaces[*].id, count.index)

  key      = "TFC_AWS_RUN_ROLE_ARN"
  value    = aws_iam_role.tfc_role.arn
  category = "env"

  description = "The AWS role arn runs will use to authenticate."
}
