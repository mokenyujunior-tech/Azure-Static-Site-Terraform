###############################################################################
# providers.tf — Workload
# ----------------------------------------------------------------------------
# Provider configuration for the main static site infrastructure.
# Uses the same Terraform and AzureRM versions as the bootstrap folder.
#
# Reference:
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatecvd0411"
    container_name       = "tfstate"
    key                  = "staticsite-workload.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
