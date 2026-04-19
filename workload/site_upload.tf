###############################################################################
# site_upload.tf — Workload
# ----------------------------------------------------------------------------
# Uploads website files to BOTH storage accounts automatically during
# terraform apply. These run BEFORE Front Door is created (Terraform
# dependency chain), so Front Door's first health probe finds a working
# site — no 404 caching, no propagation delay.
#
# To add new files: add an entry to the locals map below.
# To update files: edit the file locally, run terraform apply — Terraform
# detects the change via content_md5 and re-uploads only modified files.
#
# Reference:
#   https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-static-website-terraform
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_blob
###############################################################################

locals {
  site_files = {
    "index.html"    = { path = "../site/index.html",    type = "text/html" }
    "404.html"      = { path = "../site/404.html",      type = "text/html" }
    "css/style.css" = { path = "../site/css/style.css", type = "text/css" }
    "js/main.js"    = { path = "../site/js/main.js",    type = "application/javascript" }
  }
}

# ─── Upload to Primary Storage ──────────────────────────────────────────────
resource "azurerm_storage_blob" "primary" {
  for_each               = local.site_files
  name                   = each.key
  storage_account_name   = azurerm_storage_account.primary.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = each.value.type
  source                 = each.value.path
  content_md5            = filemd5(each.value.path)

  depends_on = [azurerm_storage_account_static_website.primary]
}

# ─── Upload to Secondary Storage ────────────────────────────────────────────
resource "azurerm_storage_blob" "secondary" {
  for_each               = local.site_files
  name                   = each.key
  storage_account_name   = azurerm_storage_account.secondary.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = each.value.type
  source                 = each.value.path
  content_md5            = filemd5(each.value.path)

  depends_on = [azurerm_storage_account_static_website.secondary]
}