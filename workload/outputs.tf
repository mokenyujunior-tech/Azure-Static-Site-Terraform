###############################################################################
# outputs.tf — Workload
# ----------------------------------------------------------------------------
# Prints the most important information after terraform apply:
#   - Live URLs to visit in your browser
#   - CLI commands to upload website files to both storage accounts
#   - Front Door profile ID (for troubleshooting)
#   - Storage account names (for reference)
#
# These outputs are also accessible later via: terraform output
###############################################################################

# ─── Live URLs ──────────────────────────────────────────────────────────────

output "site_url_apex" {
  description = "Your live site URL (apex domain). Visit this in your browser."
  value       = "https://${var.dns_zone_name}"
}

output "site_url_www" {
  description = "Your live site URL (www subdomain). Visit this in your browser."
  value       = "https://www.${var.dns_zone_name}"
}

output "frontdoor_endpoint_url" {
  description = "The Front Door endpoint URL (*.azurefd.net). Always works, even without custom domain."
  value       = "https://${azurerm_cdn_frontdoor_endpoint.main.host_name}"
}

# ─── Storage Account Names ──────────────────────────────────────────────────

output "primary_storage_account_name" {
  description = "Name of the primary storage account (Canada Central)."
  value       = azurerm_storage_account.primary.name
}

output "secondary_storage_account_name" {
  description = "Name of the secondary storage account (East US)."
  value       = azurerm_storage_account.secondary.name
}

output "primary_web_endpoint" {
  description = "Primary storage static website endpoint (should be blocked by firewall)."
  value       = azurerm_storage_account.primary.primary_web_endpoint
}

output "secondary_web_endpoint" {
  description = "Secondary storage static website endpoint (should be blocked by firewall)."
  value       = azurerm_storage_account.secondary.primary_web_endpoint
}

# ─── Upload Commands ────────────────────────────────────────────────────────
# Copy-paste these after terraform apply to upload your website files.
# You MUST upload to BOTH storage accounts for multi-region failover to work.

output "upload_command_primary" {
  description = "Run this command to upload website files to the primary storage account."
  value       = "az storage blob upload-batch --account-name ${azurerm_storage_account.primary.name} --source ./site --destination '$web' --auth-mode login --overwrite true"
}

output "upload_command_secondary" {
  description = "Run this command to upload website files to the secondary storage account."
  value       = "az storage blob upload-batch --account-name ${azurerm_storage_account.secondary.name} --source ./site --destination '$web' --auth-mode login --overwrite true"
}

# ─── Front Door Details ─────────────────────────────────────────────────────

output "frontdoor_profile_id" {
  description = "Front Door profile resource ID. Useful for CLI commands and troubleshooting."
  value       = azurerm_cdn_frontdoor_profile.main.id
}

output "frontdoor_profile_name" {
  description = "Front Door profile name."
  value       = azurerm_cdn_frontdoor_profile.main.name
}

# ─── Monitoring ─────────────────────────────────────────────────────────────

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name. Query logs in the Azure portal under this workspace."
  value       = azurerm_log_analytics_workspace.main.name
}
