variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "tfc_aws_audience" {
  type        = string
  default     = "aws.workload.identity"
  description = "The audience value to use in run identity tokens"
}

variable "tfc_hostname" {
  type        = string
  default     = "app.terraform.io"
  description = "The hostname of the TFC or TFE instance you'd like to use with AWS"
}

variable "tfc_organization_name" {
  type        = string
  description = "The name of your Terraform Cloud organization"
}

variable "tfc_project_name" {
  type        = string
  default     = "Default Project"
  description = "The project under which a workspace will be created"
}

variable "tfc_workspaces" {
  type        = map(any)
  description = "Terraform Cloud Workspaces"
  default     = {
    testing-network-layer = {
      working_directory = "root-modules/terraform-testing/network-layer"
      tag_names = ["testing", "network-layer"]
    }
    testing-data-layer = {
      working_directory = "root-modules/terraform-testing/data-layer"
      tag_names = ["testing", "data-layer"]
    }
    testing-compute-layer = {
      working_directory = "root-modules/terraform-testing/compute-layer"
      tag_names = ["testing", "compute-layer"]
    }
  }
}

variable "tfc_workspace_dependencies" {
  type        = list(list(string))
  description = "Terraform Cloud Workspace Dependencies (Run Triggers) defined as [{workspace}, {depends on}]"
  default     = [
    ["testing-data-layer", "testing-network-layer"],
    ["testing-compute-layer", "testing-data-layer"]
  ]
}

