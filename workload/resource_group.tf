###############################################################################
# resource_group.tf — Workload
# ----------------------------------------------------------------------------
# Creates the DISPOSABLE resource group that holds all workload resources:
# storage accounts, Front Door, Log Analytics, etc.
#
# You can run "terraform destroy" on this folder freely. The DNS zone in
# rg-dns-shared (created by the bootstrap folder) is untouched.
#
# The random_string generates a 4-character suffix for globally unique
# storage account names. This suffix is stable across applies (it only
# changes if you destroy and recreate).
#
# Reference:
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
###############################################################################

# ─── Random Suffix ───────────────────────────────────────────────────────────
# Storage account names must be globally unique. This random suffix ensures
# your names don't collide with anyone else's.
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

# ─── Workload Resource Group ─────────────────────────────────────────────────
resource "azurerm_resource_group" "workload" {
  name     = var.resource_group_name
  location = var.primary_location
  tags     = var.common_tags
}
