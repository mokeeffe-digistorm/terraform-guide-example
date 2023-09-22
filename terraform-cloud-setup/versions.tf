terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.17"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.48"
    }
  }
}
