###############################################################################
# storage_secondary.tf — Workload
# ----------------------------------------------------------------------------
# Creates the SECONDARY storage account in East US.
# This is the failover origin — if Canada Central goes down, Front Door
# automatically routes visitors to this origin instead.
#
# MULTI-REGION PATTERN:
#   In real companies, they have two (or more) storage accounts in different
#   regions inside the same Front Door origin group. Front Door health-probes
#   both origins and routes visitors to the nearest healthy one based on
#   latency. If one region fails, the other takes over automatically with
#   zero manual intervention. This is the professional standard.
#
# The configuration is identical to the primary storage account except
# for the location and the name suffix.
#
# IMPORTANT: You must upload your website files to BOTH storage accounts.
#   The upload commands in outputs.tf include both accounts.
#
# Reference:
#   https://learn.microsoft.com/en-us/azure/frontdoor/origin
#   https://learn.microsoft.com/en-us/azure/frontdoor/routing-methods
###############################################################################

# ─── Secondary Storage Account ──────────────────────────────────────────────
resource "azurerm_storage_account" "secondary" {
  name                = "st${var.project_short_name}sec${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.workload.name
  location            = var.secondary_location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = true
  public_network_access_enabled   = true

  tags = merge(var.common_tags, {
    costcategory = "Storage"
    region       = var.secondary_location
  })
}

# ─── Enable Static Website on Secondary ─────────────────────────────────────
resource "azurerm_storage_account_static_website" "secondary" {
  storage_account_id = azurerm_storage_account.secondary.id
  index_document     = "index.html"
  error_404_document = "404.html"
}
