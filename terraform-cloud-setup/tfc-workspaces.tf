# Terraform Cloud provider
#
# https://registry.terraform.io/providers/hashicorp/tfe/latest/docs
provider "tfe" {
  hostname = var.tfc_hostname
}

# Runs in this workspace will be automatically authenticated
# to AWS with the permissions set in the AWS policy.
#
# https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace
resource "tfe_workspace" "workspaces" {
  for_each          = var.tfc_workspaces
  name              = each.key
  organization      = var.tfc_organization_name
  working_directory = each.value.working_directory
  tag_names         = tolist(each.value.tag_names)
  vcs_repo {
    github_app_installation_id = "ghain-SnFX2gGE4JVJ6KT7"
    identifier                 = "mokeeffe-digistorm/terraform-guide-example"
    ingress_submodules         = false
  }
}

# Add a Run Trigger to workspaces that are dependent on other workspaces
#
# https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/run_trigger
resource "tfe_run_trigger" "run_triggers" {
  count         = length(var.tfc_workspace_dependencies)
  # Get the ID of the workspace by using the value of the workspace dependency at index 0
  workspace_id  = tfe_workspace.workspaces[element(element(var.tfc_workspace_dependencies, count.index), 0)].id
  # Get the ID of the "sourceable" workspace by using the value of the workspace dependency at index 1
  sourceable_id = tfe_workspace.workspaces[element(element(var.tfc_workspace_dependencies, count.index), 1)].id
}

# The following variables must be set to allow runs
# to authenticate to AWS.
#
# https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable
resource "tfe_variable" "enable_aws_provider_auth" {
  for_each     = var.tfc_workspaces
  workspace_id = tfe_workspace.workspaces[each.key].id

  key      = "TFC_AWS_PROVIDER_AUTH"
  value    = "true"
  category = "env"

  description = "Enable the Workload Identity integration for AWS."
}

resource "tfe_variable" "tfc_aws_role_arn" {
  for_each     = var.tfc_workspaces
  workspace_id = tfe_workspace.workspaces[each.key].id

  key      = "TFC_AWS_RUN_ROLE_ARN"
  value    = aws_iam_role.tfc_role.arn
  category = "env"

  description = "The AWS role arn runs will use to authenticate."
}

resource "tfe_variable" "aws_region" {
  for_each     = var.tfc_workspaces
  workspace_id = tfe_workspace.workspaces[each.key].id

  key      = "AWS_REGION"
  value    = var.region
  category = "env"

  description = "The AWS region."
}
