###############################################################################
# storage_primary.tf — Workload
# ----------------------------------------------------------------------------
# Creates the PRIMARY storage account in Canada Central.
# This is the main origin for Front Door — the "kitchen" where your website
# files live.
#
# KEY DECISIONS:
#   - StorageV2:     Required for static website hosting.
#   - Standard tier: Premium is for high-IOPS workloads, not static sites.
#   - LRS:           3 copies in one datacenter. Cheapest option. Front Door
#                    cache is the real availability layer, and we have a
#                    secondary origin in East US for failover.
#   - Hot access:    Files are read frequently (it's a website).
#   - No soft delete / versioning: Files are version-controlled in Git.
#                    Disabling these avoids accumulating storage costs from
#                    retained deleted blobs.
#
# IMPORTANT: The storage account starts with public access OPEN.
#   Front Door needs to reach it during setup. We lock it down AFTER
#   Front Door is connected (see storage_firewall.tf).
#
# Reference:
#   https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website
#   https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-static-website-terraform
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
###############################################################################

# ─── Primary Storage Account ────────────────────────────────────────────────
resource "azurerm_storage_account" "primary" {
  name                = "st${var.project_short_name}pri${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.workload.name
  location            = var.primary_location

  # ── Performance & redundancy ──
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  # ── Security ──
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = true   # Required: $web needs anonymous read
  public_network_access_enabled   = true   # Required initially; locked down later

  tags = merge(var.common_tags, {
    costcategory = "Storage"
    region       = var.primary_location
  })
}

# ─── Enable Static Website ──────────────────────────────────────────────────
# This creates the $web container automatically and enables the static
# website endpoint (*.z##.web.core.windows.net).
#
# index_document:     Served when visitors hit the root URL.
# error_404_document: Served when visitors request a path that doesn't exist.
resource "azurerm_storage_account_static_website" "primary" {
  storage_account_id = azurerm_storage_account.primary.id
  index_document     = "index.html"
  error_404_document = "404.html"
}
