###############################################################################
# providers.tf — Bootstrap
# ----------------------------------------------------------------------------
# Provider configuration for the one-time DNS zone deployment.
# This file is identical in structure to the workload providers.tf so that
# both folders use the same Terraform and AzureRM versions.
#
# Reference:
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
